import { Request, Response } from 'express';

export const listPrinters = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const printers = await req.propertyDb.models.restaurant_printers.findAll({
      where: { outlet_id },
      order: [['printer_name', 'ASC']]
    });
    return res.json({ success: true, data: printers });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
};

export const createPrinter = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { printer_name, printer_type, ip_address, port, status } = req.body;
    const printer = await req.propertyDb.models.restaurant_printers.create({
      outlet_id,
      printer_name,
      printer_type: printer_type || 'NETWORK',
      ip_address,
      port,
      status: status || 'ACTIVE'
    });
    return res.json({ success: true, data: printer });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const updatePrinter = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { id } = req.params;
    const { printer_name, printer_type, ip_address, port, status } = req.body;
    const printer = await req.propertyDb.models.restaurant_printers.findOne({ where: { id, outlet_id } });
    if (!printer) return res.status(404).json({ success: false, message: 'Printer not found' });

    await printer.update({ printer_name, printer_type, ip_address, port, status });
    return res.json({ success: true, data: printer });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const deletePrinter = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { id } = req.params;
    const printer = await req.propertyDb.models.restaurant_printers.findOne({ where: { id, outlet_id } });
    if (!printer) return res.status(404).json({ success: false, message: 'Printer not found' });

    await printer.destroy();
    return res.json({ success: true, message: 'Printer deleted successfully' });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const listKitchenStations = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const stations = await req.propertyDb.models.kitchen_stations.findAll({
      where: { outlet_id },
      include: [
        { model: req.propertyDb.models.restaurant_printers, as: 'printer', attributes: ['printer_name'] }
      ],
      order: [['station_name', 'ASC']]
    });
    return res.json({ success: true, data: stations });
  } catch (err: any) {
    return res.status(500).json({ success: false, error: err.message });
  }
};

export const createKitchenStation = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { station_name, printer_id, status } = req.body;
    const station = await req.propertyDb.models.kitchen_stations.create({
      outlet_id,
      station_name,
      printer_id,
      status: status || 'ACTIVE'
    });
    return res.json({ success: true, data: station });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const updateKitchenStation = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { id } = req.params;
    const { station_name, printer_id, status } = req.body;
    const station = await req.propertyDb.models.kitchen_stations.findOne({ where: { id, outlet_id } });
    if (!station) return res.status(404).json({ success: false, message: 'Kitchen Station not found' });

    await station.update({ station_name, printer_id, status });
    return res.json({ success: true, data: station });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

export const deleteKitchenStation = async (req: Request, res: Response): Promise<any> => {
  try {
    const outlet_id = req.user.outlet_id;
    const { id } = req.params;
    const station = await req.propertyDb.models.kitchen_stations.findOne({ where: { id, outlet_id } });
    if (!station) return res.status(404).json({ success: false, message: 'Kitchen Station not found' });

    await station.destroy();
    return res.json({ success: true, message: 'Kitchen Station deleted successfully' });
  } catch (err: any) {
    return res.status(400).json({ success: false, error: err.message });
  }
};

module.exports = {
  listPrinters,
  createPrinter,
  updatePrinter,
  deletePrinter,
  listKitchenStations,
  createKitchenStation,
  updateKitchenStation,
  deleteKitchenStation
};
