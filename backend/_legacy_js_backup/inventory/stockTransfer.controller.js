const { Op } = require('sequelize');
const bcrypt = require('bcryptjs');

exports.createDispatch = async (req, res) => {
    try {
        const { destination_outlet_id, items, notes } = req.body;
        const source_outlet_id = req.outlet?.id || req.user?.outlet_id;

        if (!source_outlet_id) {
            return res.status(400).json({ success: false, message: 'Source outlet is required' });
        }

        if (!destination_outlet_id) {
            return res.status(400).json({ success: false, message: 'Destination outlet is required' });
        }

        if (Number(source_outlet_id) === Number(destination_outlet_id)) {
            return res.status(400).json({ success: false, message: 'Source and destination outlets must be different' });
        }

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({ success: false, message: 'At least one item is required for stock transfer' });
        }

        const models = req.propertyDb.models;

        // Verify destination outlet exists
        const destOutlet = await models.outlets.findByPk(destination_outlet_id, { bypassOutletFilter: true });
        if (!destOutlet) {
            return res.status(404).json({ success: false, message: 'Destination outlet not found' });
        }

        // Generate unique transfer number ST-YYYYMMDD-XXXX
        const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
        const count = await models.stock_transfer_headers.count({ bypassOutletFilter: true });
        const transfer_no = `ST-${dateStr}-${(count + 1).toString().padStart(4, '0')}`;

        let totalQty = 0;
        let totalAmount = 0;

        items.forEach(item => {
            const qty = parseFloat(item.transfer_qty) || 0;
            const cost = parseFloat(item.unit_cost) || 0;
            totalQty += qty;
            totalAmount += (qty * cost);
        });

        // Create Header
        const header = await models.stock_transfer_headers.create({
            transfer_no,
            source_outlet_id,
            destination_outlet_id,
            status: 'DISPATCHED',
            dispatch_date: new Date(),
            total_qty: totalQty,
            total_amount: totalAmount,
            dispatched_by_user_id: req.user?.id || null,
            notes: notes || ''
        }, { bypassOutletFilter: true });

        // Create Items & Debit Stock Ledger for Source Outlet
        for (const item of items) {
            const qty = parseFloat(item.transfer_qty) || 0;
            const cost = parseFloat(item.unit_cost) || 0;

            await models.stock_transfer_items.create({
                transfer_id: header.id,
                item_id: item.item_id || null,
                item_code: item.item_code,
                item_name: item.item_name || item.item_code,
                transfer_qty: qty,
                unit_cost: cost,
                total_cost: qty * cost
            }, { bypassOutletFilter: true });

            // Record Debit in stock_ledger for Source Outlet (100 transferred = 100 debited)
            if (models.stock_ledger) {
                // Get current stock balance for item at source outlet
                const lastLedger = await models.stock_ledger.findOne({
                    where: { outlet_id: source_outlet_id, item_code: item.item_code },
                    order: [['id', 'DESC']],
                    bypassOutletFilter: true
                });

                const currentBal = lastLedger ? parseFloat(lastLedger.balance || 0) : 0;
                const newBal = currentBal - qty;

                await models.stock_ledger.create({
                    outlet_id: source_outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date().toISOString().split('T')[0],
                    txn_type: 'TRANSFER_DISPATCH_OUT',
                    ref_no: transfer_no,
                    qty_in: 0,
                    qty_out: qty,
                    balance: newBal
                }, { bypassOutletFilter: true });
            }
        }

        return res.json({
            success: true,
            message: `Stock transfer ${transfer_no} dispatched successfully`,
            data: header
        });
    } catch (error) {
        console.error('Error creating stock dispatch:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.receiveTransfer = async (req, res) => {
    try {
        const transferId = req.params.id;
        const receiving_outlet_id = req.outlet?.id || req.user?.outlet_id;
        const models = req.propertyDb.models;

        const header = await models.stock_transfer_headers.findByPk(transferId, { bypassOutletFilter: true });
        if (!header) {
            return res.status(404).json({ success: false, message: 'Stock transfer record not found' });
        }

        if (header.status === 'COMPLETED' || header.status === 'RECEIVED') {
            return res.status(400).json({ success: false, message: 'This stock transfer has already been received' });
        }

        if (header.status === 'CANCELLED') {
            return res.status(400).json({ success: false, message: 'Cannot receive a cancelled transfer' });
        }

        const transferItems = await models.stock_transfer_items.findAll({
            where: { transfer_id: header.id },
            bypassOutletFilter: true
        });

        // Credit 100% of transferred quantity to Destination Outlet stock ledger
        for (const item of transferItems) {
            const qty = parseFloat(item.transfer_qty) || 0;

            // Ensure item exists in destination outlet's item_master catalog
            if (models.item_master) {
                try {
                    const destItem = await models.item_master.findOne({
                        where: { outlet_id: header.destination_outlet_id, item_code: item.item_code },
                        bypassOutletFilter: true
                    });

                    if (!destItem) {
                        const sourceItem = await models.item_master.findOne({
                            where: { outlet_id: header.source_outlet_id, item_code: item.item_code },
                            bypassOutletFilter: true
                        });

                        if (sourceItem) {
                            const itemData = sourceItem.toJSON ? sourceItem.toJSON() : { ...(sourceItem.dataValues || sourceItem) };
                            delete itemData.id;
                            delete itemData.created_at;
                            delete itemData.updated_at;
                            delete itemData.createdAt;
                            delete itemData.updatedAt;
                            itemData.outlet_id = header.destination_outlet_id;
                            itemData.opening_balance = 0;
                            await models.item_master.create(itemData, { bypassOutletFilter: true });
                        } else {
                            let cleanName = item.item_name || item.item_code;
                            let extractedBrand = 'GENERAL';
                            if (cleanName.includes('(') && cleanName.includes(')')) {
                                const parts = cleanName.split('(');
                                cleanName = parts[0].trim();
                                extractedBrand = parts[1].replace(')', '').trim();
                            }

                            await models.item_master.create({
                                outlet_id: header.destination_outlet_id,
                                item_code: item.item_code,
                                item_name: cleanName,
                                item_group: 'GENERAL',
                                sub_category: 'GENERAL',
                                brand: extractedBrand,
                                unit: 'NOS',
                                rate: parseFloat(item.unit_cost) || 0,
                                retail_sale_price: parseFloat(item.unit_cost) || 0,
                                opening_balance: 0,
                                is_active: true,
                                is_saleable: true,
                                stockable: true
                            }, { bypassOutletFilter: true });
                        }
                    }
                } catch (itemErr) {
                    console.warn('Notice syncing item master for destination outlet:', itemErr.message);
                }
            }

            if (models.stock_ledger) {
                // Get current stock balance for item at destination outlet
                const lastLedger = await models.stock_ledger.findOne({
                    where: { outlet_id: header.destination_outlet_id, item_code: item.item_code },
                    order: [['id', 'DESC']],
                    bypassOutletFilter: true
                });

                const currentBal = lastLedger ? parseFloat(lastLedger.balance || 0) : 0;
                const newBal = currentBal + qty;

                await models.stock_ledger.create({
                    outlet_id: header.destination_outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date().toISOString().split('T')[0],
                    txn_type: 'TRANSFER_RECEIVE_IN',
                    ref_no: header.transfer_no,
                    qty_in: qty,
                    qty_out: 0,
                    balance: newBal
                }, { bypassOutletFilter: true });
            }
        }

        await header.update({
            status: 'COMPLETED',
            received_date: new Date(),
            received_by_user_id: req.user?.id || null
        }, { bypassOutletFilter: true });

        return res.json({
            success: true,
            message: `Stock transfer ${header.transfer_no} received successfully. Stock credited to outlet.`,
            data: header
        });
    } catch (error) {
        console.error('Error receiving stock transfer:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

async function attachItemsToTransfers(models, transfers) {
    if (!transfers || transfers.length === 0) return [];
    const transferIds = transfers.map(t => t.id);
    const allItems = await models.stock_transfer_items.findAll({
        where: { transfer_id: transferIds },
        bypassOutletFilter: true
    });

    return transfers.map(t => {
        const tJson = t.toJSON ? t.toJSON() : { ...t };
        tJson.items = allItems.filter(i => i.transfer_id === t.id);
        if (tJson.items && tJson.items.length > 0) {
            tJson.item_summary = tJson.items.map(i => `${i.item_name || i.item_code} (x${i.transfer_qty})`).join(', ');
        } else {
            tJson.item_summary = `Qty: ${tJson.total_qty || 0}`;
        }
        return tJson;
    });
}

exports.getOverallProgress = async (req, res) => {
    try {
        const models = req.propertyDb.models;
        const currentOutletId = req.outlet?.id || req.user?.outlet_id;

        const allOutlets = await models.outlets.findAll({
            where: { is_active: true },
            bypassOutletFilter: true
        });

        // Filter: ONLY current Master Outlet and its explicitly linked child outlets!
        const relevantOutlets = allOutlets.filter(o => 
            Number(o.id) === Number(currentOutletId) || 
            Number(o.parent_outlet_id) === Number(currentOutletId)
        );

        const transfersRaw = await models.stock_transfer_headers.findAll({
            where: {
                [Op.or]: [
                    { source_outlet_id: currentOutletId },
                    { destination_outlet_id: currentOutletId }
                ]
            },
            order: [['created_at', 'DESC']],
            bypassOutletFilter: true
        });

        const transfers = await attachItemsToTransfers(models, transfersRaw);

        let totalDispatches = transfers.length;
        let totalCompleted = transfers.filter(t => t.status === 'COMPLETED' || t.status === 'RECEIVED').length;
        let totalInTransit = transfers.filter(t => t.status === 'DISPATCHED' || t.status === 'IN_TRANSIT').length;
        let totalQtyTransferred = transfers.reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);
        let totalValueTransferred = transfers.reduce((sum, t) => sum + parseFloat(t.total_amount || 0), 0);

        // Map outlet stats only for relevant (linked) outlets
        const outletStats = relevantOutlets.map(outlet => {
            const outgoing = transfers.filter(t => t.source_outlet_id === outlet.id);
            const incoming = transfers.filter(t => t.destination_outlet_id === outlet.id);

            const dispatchedQty = outgoing.reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);
            const receivedQty = incoming.filter(t => t.status === 'COMPLETED' || t.status === 'RECEIVED')
                .reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);
            const inTransitIncomingQty = incoming.filter(t => t.status === 'DISPATCHED' || t.status === 'IN_TRANSIT')
                .reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);

            return {
                outlet_id: outlet.id,
                outlet_code: outlet.outlet_code,
                outlet_name: outlet.outlet_name,
                outlet_type: outlet.outlet_type,
                is_master: outlet.is_master || outlet.outlet_role === 'MASTER',
                outgoing_transfers_count: outgoing.length,
                incoming_transfers_count: incoming.length,
                dispatched_qty: dispatchedQty,
                received_qty: receivedQty,
                in_transit_qty: inTransitIncomingQty
            };
        });

        return res.json({
            success: true,
            data: {
                overall_summary: {
                    total_dispatches: totalDispatches,
                    total_completed: totalCompleted,
                    total_in_transit: totalInTransit,
                    total_qty_transferred: totalQtyTransferred,
                    total_value_transferred: totalValueTransferred
                },
                outlets_progress: outletStats,
                recent_transfers: transfers.slice(0, 10)
            }
        });
    } catch (error) {
        console.error('Error fetching overall progress:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.getIndividualOutletProgress = async (req, res) => {
    try {
        const outletId = req.params.outlet_id || req.outlet?.id || req.user?.outlet_id;
        const models = req.propertyDb.models;

        const outlet = await models.outlets.findByPk(outletId, { bypassOutletFilter: true });
        if (!outlet) {
            return res.status(404).json({ success: false, message: 'Outlet not found' });
        }

        const outgoingRaw = await models.stock_transfer_headers.findAll({
            where: { source_outlet_id: outletId },
            order: [['created_at', 'DESC']],
            bypassOutletFilter: true
        });

        const incomingRaw = await models.stock_transfer_headers.findAll({
            where: { destination_outlet_id: outletId },
            order: [['created_at', 'DESC']],
            bypassOutletFilter: true
        });

        const outgoingTransfers = await attachItemsToTransfers(models, outgoingRaw);
        const incomingTransfers = await attachItemsToTransfers(models, incomingRaw);

        const totalDispatchedQty = outgoingTransfers.reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);
        const totalReceivedQty = incomingTransfers.filter(t => t.status === 'COMPLETED' || t.status === 'RECEIVED')
            .reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);
        const totalInTransitQty = incomingTransfers.filter(t => t.status === 'DISPATCHED' || t.status === 'IN_TRANSIT')
            .reduce((sum, t) => sum + parseFloat(t.total_qty || 0), 0);

        return res.json({
            success: true,
            data: {
                outlet: {
                    id: outlet.id,
                    outlet_code: outlet.outlet_code,
                    outlet_name: outlet.outlet_name,
                    outlet_type: outlet.outlet_type,
                    is_master: outlet.is_master || false
                },
                summary: {
                    total_outgoing_count: outgoingTransfers.length,
                    total_incoming_count: incomingTransfers.length,
                    total_dispatched_qty: totalDispatchedQty,
                    total_received_qty: totalReceivedQty,
                    total_in_transit_qty: totalInTransitQty
                },
                outgoing_transfers: outgoingTransfers,
                incoming_transfers: incomingTransfers
            }
        });
    } catch (error) {
        console.error('Error fetching individual outlet progress:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.listTransfers = async (req, res) => {
    try {
        const { outlet_id, status } = req.query;
        const models = req.propertyDb.models;

        const whereClause = {};
        if (status) {
            whereClause.status = status;
        }

        if (outlet_id) {
            whereClause[Op.or] = [
                { source_outlet_id: outlet_id },
                { destination_outlet_id: outlet_id }
            ];
        }

        const transfersRaw = await models.stock_transfer_headers.findAll({
            where: whereClause,
            order: [['created_at', 'DESC']],
            bypassOutletFilter: true
        });

        const transfers = await attachItemsToTransfers(models, transfersRaw);

        return res.json({ success: true, data: transfers });
    } catch (error) {
        console.error('Error listing stock transfers:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.getTransferDetails = async (req, res) => {
    try {
        const transferId = req.params.id;
        const models = req.propertyDb.models;

        const header = await models.stock_transfer_headers.findByPk(transferId, { bypassOutletFilter: true });
        if (!header) {
            return res.status(404).json({ success: false, message: 'Stock transfer not found' });
        }

        const items = await models.stock_transfer_items.findAll({
            where: { transfer_id: header.id },
            bypassOutletFilter: true
        });

        const sourceOutlet = await models.outlets.findByPk(header.source_outlet_id, { bypassOutletFilter: true });
        const destOutlet = await models.outlets.findByPk(header.destination_outlet_id, { bypassOutletFilter: true });

        return res.json({
            success: true,
            data: {
                header,
                items,
                source_outlet: sourceOutlet ? { id: sourceOutlet.id, name: sourceOutlet.outlet_name, code: sourceOutlet.outlet_code } : null,
                destination_outlet: destOutlet ? { id: destOutlet.id, name: destOutlet.outlet_name, code: destOutlet.outlet_code } : null
            }
        });
    } catch (error) {
        console.error('Error getting transfer details:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.getOutletsHierarchy = async (req, res) => {
    try {
        const models = req.propertyDb.models;
        const currentOutletId = Number(req.outlet?.id || req.user?.outlet_id);

        const rawOutlets = await models.outlets.findAll({
            where: { is_active: true },
            bypassOutletFilter: true
        });

        // Robust master detection helper: an outlet is master if explicitly flagged or role is MASTER
        const isMasterOutlet = (o) => {
            if (!o) return false;
            return Boolean(o.is_master) || String(o.is_master) === '1' || o.outlet_role === 'MASTER';
        };

        const outlets = rawOutlets.map(o => {
            const json = o.toJSON ? o.toJSON() : { ...o };
            const isMaster = isMasterOutlet(json);
            return {
                ...json,
                is_master: isMaster,
                outlet_role: isMaster ? 'MASTER' : (json.parent_outlet_id ? 'BRANCH' : 'SINGLE')
            };
        });

        const currentOutlet = outlets.find(o => Number(o.id) === currentOutletId) || outlets[0];
        const isCurrentMaster = currentOutlet?.is_master === true;

        // Determine master outlet for current session
        let masterOutletId = isCurrentMaster ? currentOutlet.id : currentOutlet?.parent_outlet_id;
        if (!masterOutletId) masterOutletId = currentOutlet?.id;

        const masterOutlet = outlets.find(o => Number(o.id) === Number(masterOutletId)) || currentOutlet;

        // Child outlets linked directly under the current outlet
        const childOutletsForCurrent = outlets.filter(o => Number(o.parent_outlet_id) === Number(currentOutlet.id) && Number(o.id) !== Number(currentOutlet.id));

        // Allowed view scope: Master outlets see themselves + linked child outlets. Branch/Standalone outlets see ONLY themselves.
        const allowedOutletsForSession = outlets.filter(o => {
            const oid = Number(o.id);
            const pid = o.parent_outlet_id ? Number(o.parent_outlet_id) : null;

            if (oid === Number(currentOutlet.id)) return true;
            if (isCurrentMaster && pid === Number(currentOutlet.id)) return true;
            return false;
        });

        const masterOutlets = outlets.filter(o => o.is_master);

        let shareContactInfo = true;
        if (models.system_settings) {
            try {
                const setting = await models.system_settings.findOne({ where: { outlet_id: currentOutletId }, bypassOutletFilter: true });
                if (setting && setting.share_contact_info !== undefined && setting.share_contact_info !== null) {
                    shareContactInfo = Boolean(setting.share_contact_info);
                }
            } catch (_) {}
        }

        return res.json({
            success: true,
            data: {
                current_outlet: currentOutlet,
                master_outlet: masterOutlet,
                all_outlets: allowedOutletsForSession,
                master_outlets: masterOutlets,
                child_outlets: childOutletsForCurrent,
                linked_child_outlets: childOutletsForCurrent,
                share_contact_info: shareContactInfo,
                is_master: isCurrentMaster,
                can_manage_hierarchy: true
            }
        });
    } catch (error) {
        console.error('Error getting outlets hierarchy:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.unlinkOutlet = async (req, res) => {
    try {
        const { target_outlet_id } = req.body;
        const models = req.propertyDb.models;

        const outletIdToUnlink = target_outlet_id || req.outlet?.id || req.user?.outlet_id;
        const outlet = await models.outlets.findByPk(outletIdToUnlink, { bypassOutletFilter: true });
        if (!outlet) {
            return res.status(404).json({ success: false, message: 'Outlet not found' });
        }

        await outlet.update({
            parent_outlet_id: null,
            is_master: false,
            outlet_role: 'BRANCH'
        }, { bypassOutletFilter: true });

        return res.json({
            success: true,
            message: `Outlet ${outlet.outlet_name} (${outlet.outlet_code}) unlinked successfully`,
            data: outlet
        });
    } catch (error) {
        console.error('Error unlinking outlet:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.toggleContactSharing = async (req, res) => {
    try {
        const outletId = req.outlet?.id || req.user?.outlet_id;
        const { share_contact_info } = req.body;
        const models = req.propertyDb.models;

        if (models.system_settings) {
            try {
                let setting = await models.system_settings.findOne({ where: { outlet_id: outletId }, bypassOutletFilter: true });
                if (setting) {
                    await setting.update({ share_contact_info: !!share_contact_info }, { bypassOutletFilter: true });
                } else {
                    await models.system_settings.create({ outlet_id: outletId, share_contact_info: !!share_contact_info }, { bypassOutletFilter: true });
                }
            } catch (err) {
                console.warn('Notice setting share_contact_info:', err.message);
            }
        }

        return res.json({
            success: true,
            message: `Contact sharing ${share_contact_info ? 'enabled' : 'disabled'} successfully`,
            share_contact_info: !!share_contact_info
        });
    } catch (error) {
        console.error('Error toggling contact sharing:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.linkOutletByPin = async (req, res) => {
    try {
        const { target_outlet_code, pin, master_outlet_id } = req.body;
        const currentMasterId = master_outlet_id || req.outlet?.id || req.user?.outlet_id;
        const models = req.propertyDb.models;

        if (!target_outlet_code || !pin) {
            return res.status(400).json({ success: false, message: 'Target outlet code and PIN are required' });
        }

        const targetOutlet = await models.outlets.findOne({
            where: { outlet_code: target_outlet_code.trim(), is_active: true },
            bypassOutletFilter: true
        });

        if (!targetOutlet) {
            return res.status(404).json({ success: false, message: 'Target outlet code not found or inactive' });
        }

        if (Number(targetOutlet.id) === Number(currentMasterId)) {
            return res.status(400).json({ success: false, message: 'Cannot link an outlet to itself' });
        }

        // Verify PIN against recovery_pin_hash or supervisor_pin
        let isPinValid = false;
        if (targetOutlet.recovery_pin_hash) {
            isPinValid = await bcrypt.compare(pin.toString(), targetOutlet.recovery_pin_hash);
        }

        if (!isPinValid && targetOutlet.supervisor_pin) {
            isPinValid = (pin.toString() === targetOutlet.supervisor_pin.toString());
        }

        if (!isPinValid) {
            return res.status(401).json({ success: false, message: 'Invalid Recovery PIN for target outlet' });
        }

        // Pin is valid! Link target outlet to master outlet
        await targetOutlet.update({
            parent_outlet_id: currentMasterId,
            is_master: false,
            outlet_role: 'BRANCH'
        }, { bypassOutletFilter: true });

        return res.json({
            success: true,
            message: `Outlet ${targetOutlet.outlet_name} (${targetOutlet.outlet_code}) linked successfully!`,
            data: targetOutlet
        });
    } catch (error) {
        console.error('Error linking outlet by PIN:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.setOutletRole = async (req, res) => {
    try {
        const { outlet_id, is_master, parent_outlet_id, outlet_role } = req.body;
        const models = req.propertyDb.models;

        const outlet = await models.outlets.findByPk(outlet_id, { bypassOutletFilter: true });
        if (!outlet) {
            return res.status(404).json({ success: false, message: 'Outlet not found' });
        }

        await outlet.update({
            is_master: is_master !== undefined ? is_master : outlet.is_master,
            parent_outlet_id: parent_outlet_id !== undefined ? parent_outlet_id : outlet.parent_outlet_id,
            outlet_role: outlet_role || (is_master ? 'MASTER' : 'BRANCH')
        }, { bypassOutletFilter: true });

        return res.json({
            success: true,
            message: `Outlet ${outlet.outlet_name} updated successfully`,
            data: outlet
        });
    } catch (error) {
        console.error('Error setting outlet role:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

const fs = require('fs');
const path = require('path');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const OTP_STORE_FILE = path.join(rootDir, "data", "otp_store.json");

function readOtpStore() {
    try {
        if (!fs.existsSync(OTP_STORE_FILE)) return {};
        return JSON.parse(fs.readFileSync(OTP_STORE_FILE, "utf8")) || {};
    } catch (_) { return {}; }
}

function writeOtpStore(store) {
    try {
        fs.mkdirSync(path.dirname(OTP_STORE_FILE), { recursive: true });
        fs.writeFileSync(OTP_STORE_FILE, JSON.stringify(store, null, 2));
    } catch (_) {}
}

exports.requestLinkOtp = async (req, res) => {
    try {
        const { target_outlet_code } = req.body;
        const models = req.propertyDb.models;

        if (!target_outlet_code) {
            return res.status(400).json({ success: false, message: 'Target outlet code is required' });
        }

        const targetOutlet = await models.outlets.findOne({
            where: { outlet_code: target_outlet_code.trim(), is_active: true },
            bypassOutletFilter: true
        });

        if (!targetOutlet) {
            return res.status(404).json({ success: false, message: 'Target outlet code not found or inactive' });
        }

        // Generate 6 digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const store = readOtpStore();
        const key = `LINK_OTP_${target_outlet_code.trim().toUpperCase()}`;
        store[key] = {
            otp,
            expiresAt: Date.now() + (10 * 60 * 1000) // 10 minutes
        };
        writeOtpStore(store);

        // Attempt sending email via emailService
        try {
            const emailService = require('../../modules/emailService');
            if (targetOutlet.contact_email) {
                await emailService.sendOtpEmail(targetOutlet.contact_email, otp, "Outlet Link Verification");
            }
        } catch (emailErr) {
            console.warn(`[OTP EMAIL WARN] Could not send email: ${emailErr.message}`);
        }

        return res.json({
            success: true,
            message: `OTP sent to contact email (${targetOutlet.contact_email || 'registered email'})`,
            target_outlet_name: targetOutlet.outlet_name
        });
    } catch (error) {
        console.error('Error requesting link OTP:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

exports.verifyLinkOtp = async (req, res) => {
    try {
        const { target_outlet_code, otp, master_outlet_id } = req.body;
        const currentMasterId = master_outlet_id || req.outlet?.id || req.user?.outlet_id;
        const models = req.propertyDb.models;

        if (!target_outlet_code || !otp) {
            return res.status(400).json({ success: false, message: 'Target outlet code and OTP are required' });
        }

        const key = `LINK_OTP_${target_outlet_code.trim().toUpperCase()}`;
        const store = readOtpStore();
        const record = store[key];

        if (!record || Date.now() > record.expiresAt) {
            return res.status(400).json({ success: false, message: 'OTP has expired or is invalid. Please request a new OTP.' });
        }

        if (record.otp !== otp.toString().trim()) {
            return res.status(401).json({ success: false, message: 'Incorrect OTP code.' });
        }

        const targetOutlet = await models.outlets.findOne({
            where: { outlet_code: target_outlet_code.trim(), is_active: true },
            bypassOutletFilter: true
        });

        if (!targetOutlet) {
            return res.status(404).json({ success: false, message: 'Target outlet code not found' });
        }

        // Valid OTP! Link target outlet to master outlet
        await targetOutlet.update({
            parent_outlet_id: currentMasterId,
            is_master: false,
            outlet_role: 'BRANCH'
        }, { bypassOutletFilter: true });

        // Clean OTP
        delete store[key];
        writeOtpStore(store);

        return res.json({
            success: true,
            message: `Outlet ${targetOutlet.outlet_name} (${targetOutlet.outlet_code}) verified & linked successfully via OTP!`,
            data: targetOutlet
        });
    } catch (error) {
        console.error('Error verifying link OTP:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};
