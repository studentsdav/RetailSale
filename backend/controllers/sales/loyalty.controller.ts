import { Request, Response } from 'express';
const {
  normalizeCustomerIdentity,
  resolveCustomerKey,
  getOutletConfig,
  getCustomerBalance,
  isConfigActive
} = require('../../services/loyalty.service');

function toAmount(value: any, fallback: number = 0): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toWhole(value: any, fallback: number = 0): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.floor(parsed));
}

export const getConfig = async (req: Request, res: Response): Promise<any> => {
  try {
    const row = await req.propertyDb.models.loyalty_master_config.findOne({
      where: { outlet_id: req.user.outlet_id }
    });
    const config = await getOutletConfig(req.propertyDb, req.user.outlet_id);
    const now = new Date();

    return res.json({
      success: true,
      data: {
        id: row?.id || null,
        ...config,
        active_now: isConfigActive(config, now),
        current_date: now.toISOString()
      }
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const saveConfig = async (req: Request, res: Response): Promise<any> => {
  const transaction = await req.propertyDb.transaction();
  try {
    const payload = {
      program_status: req.body.program_status === true,
      start_date: req.body.start_date || null,
      end_date: req.body.end_date || null,
      min_purchase_threshold: toAmount(req.body.min_purchase_threshold, 0),
      earning_ratio: toAmount(req.body.earning_ratio, 1000),
      redemption_value: toAmount(req.body.redemption_value, 1),
      max_redeem_per_bill: toWhole(req.body.max_redeem_per_bill, 0),
      point_expiry_days: toWhole(req.body.point_expiry_days, 90),
      updated_by: req.user.id
    };

    if (payload.earning_ratio <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Earning ratio must be greater than 0.'
      });
    }
    if (payload.redemption_value <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Redemption value must be greater than 0.'
      });
    }

    const existing = await req.propertyDb.models.loyalty_master_config.findOne({
      where: { outlet_id: req.user.outlet_id },
      transaction
    });

    let saved: any;
    if (existing) {
      saved = await existing.update(payload, { transaction });
    } else {
      saved = await req.propertyDb.models.loyalty_master_config.create(
        {
          outlet_id: req.user.outlet_id,
          created_by: req.user.id,
          ...payload
        },
        { transaction }
      );
    }

    await transaction.commit();
    return res.json({ success: true, data: saved });
  } catch (error: any) {
    await transaction.rollback();
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const getCustomerSummary = async (req: Request, res: Response): Promise<any> => {
  try {
    const config = await getOutletConfig(req.propertyDb, req.user.outlet_id);
    const identity = normalizeCustomerIdentity(req.query);
    const customerKey = resolveCustomerKey(identity);
    if (!customerKey) {
      return res.json({
        success: true,
        data: {
          customer_key: null,
          available_points: 0,
          redemption_value: config.redemption_value,
          max_redeem_per_bill: config.max_redeem_per_bill,
          program_status: config.program_status,
          active_now: false
        }
      });
    }

    const balance = await getCustomerBalance(req.propertyDb, req.user.outlet_id, identity);

    return res.json({
      success: true,
      data: {
        customer_key: balance.customer_key,
        available_points: balance.available_points,
        redemption_value: config.redemption_value,
        max_redeem_per_bill: config.max_redeem_per_bill,
        program_status: config.program_status,
        active_now: isConfigActive(config, new Date())
      }
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  getConfig,
  saveConfig,
  getCustomerSummary
};
