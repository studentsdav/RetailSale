import { Request, Response } from 'express';

const toNumber = (val: any): number => {
  const parsed = parseFloat(val);
  return Number.isFinite(parsed) ? parsed : 0;
};

export const listBillValuePromos = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user?.outlet_id;

    const rules = await req.propertyDb.models.bill_value_promos.findAll({
      where: { outlet_id },
      include: [
        {
          model: req.propertyDb.models.item_master,
          as: 'target_item',
          attributes: ['id', 'item_name', 'item_code'],
          required: false
        }
      ],
      order: [['id', 'ASC']]
    });

    return res.json({ success: true, data: rules });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const createBillValuePromo = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { name, min_bill_amount, target_item_id, discount_value, is_active } = req.body;

    if (!name || !target_item_id) {
      return res.status(400).json({ success: false, message: 'name and target_item_id are required' });
    }

    const rule = await req.propertyDb.models.bill_value_promos.create({
      outlet_id,
      name,
      min_bill_amount: toNumber(min_bill_amount || 0),
      target_item_id: Number(target_item_id),
      discount_value: toNumber(discount_value || 100),
      is_active: is_active !== false
    });

    return res.json({ success: true, data: rule });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const updateBillValuePromo = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { id } = req.params;
    const { name, min_bill_amount, target_item_id, discount_value, is_active } = req.body;

    const rule = await req.propertyDb.models.bill_value_promos.findOne({
      where: { id, outlet_id }
    });

    if (!rule) {
      return res.status(404).json({ success: false, message: 'Bill value promotion not found' });
    }

    await rule.update({
      name: name !== undefined ? name : rule.name,
      min_bill_amount: min_bill_amount !== undefined ? toNumber(min_bill_amount) : rule.min_bill_amount,
      target_item_id: target_item_id !== undefined ? Number(target_item_id) : rule.target_item_id,
      discount_value: discount_value !== undefined ? toNumber(discount_value) : rule.discount_value,
      is_active: is_active !== undefined ? is_active : rule.is_active
    });

    return res.json({ success: true, data: rule });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

export const deleteBillValuePromo = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { id } = req.params;

    const rule = await req.propertyDb.models.bill_value_promos.findOne({
      where: { id, outlet_id }
    });

    if (!rule) {
      return res.status(404).json({ success: false, message: 'Bill value promotion not found' });
    }

    await rule.destroy();
    return res.json({ success: true, message: 'Bill value promotion deleted successfully' });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  listBillValuePromos,
  createBillValuePromo,
  updateBillValuePromo,
  deleteBillValuePromo
};
