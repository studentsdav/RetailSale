const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const tableCtrl = require('../controllers/restaurant/table.controller');
const printerCtrl = require('../controllers/restaurant/printer.controller');
const emailCtrl = require('../controllers/restaurant/email.controller');

// Require authentication for all restaurant routes
router.use(auth);

// Floors
router.get('/floors', tableCtrl.listFloors);
router.post('/floors', tableCtrl.createFloor);
router.put('/floors/:id', tableCtrl.updateFloor);
router.delete('/floors/:id', tableCtrl.deleteFloor);

// Dining Areas
router.get('/dining-areas', tableCtrl.listDiningAreas);
router.post('/dining-areas', tableCtrl.createDiningArea);
router.put('/dining-areas/:id', tableCtrl.updateDiningArea);
router.delete('/dining-areas/:id', tableCtrl.deleteDiningArea);

// Table Types
router.get('/table-types', tableCtrl.listTableTypes);
router.post('/table-types', tableCtrl.createTableType);
router.put('/table-types/:id', tableCtrl.updateTableType);
router.delete('/table-types/:id', tableCtrl.deleteTableType);

// Tables & Actions
router.get('/tables', tableCtrl.listTables);
router.post('/tables', tableCtrl.createTable);
router.put('/tables/:id', tableCtrl.updateTable);
router.delete('/tables/:id', tableCtrl.deleteTable);
router.put('/tables/:id/status', tableCtrl.updateTableStatus);
router.post('/tables/transfer', tableCtrl.transferTable);
router.post('/tables/merge', tableCtrl.mergeTables);

// Reservations
router.get('/reservations', tableCtrl.listReservations);
router.post('/reservations', tableCtrl.createReservation);
router.put('/reservations/:id/status', tableCtrl.updateReservationStatus);

// Printers
router.get('/printers', printerCtrl.listPrinters);
router.post('/printers', printerCtrl.createPrinter);
router.put('/printers/:id', printerCtrl.updatePrinter);
router.delete('/printers/:id', printerCtrl.deletePrinter);

// Kitchen Stations
router.get('/kitchen-stations', printerCtrl.listKitchenStations);
router.post('/kitchen-stations', printerCtrl.createKitchenStation);
router.put('/kitchen-stations/:id', printerCtrl.updateKitchenStation);
router.delete('/kitchen-stations/:id', printerCtrl.deleteKitchenStation);

// Email Configurations & Templates
router.get('/email-configurations', emailCtrl.getEmailConfig);
router.post('/email-configurations', emailCtrl.saveEmailConfig);
router.post('/email-configurations/test', emailCtrl.testEmail);
router.get('/settings/smtp', emailCtrl.getEmailConfig);
router.post('/settings/smtp', emailCtrl.saveEmailConfig);
router.post('/settings/smtp/test', emailCtrl.testEmail);
router.get('/email-templates', emailCtrl.listTemplates);
router.post('/email-templates', emailCtrl.saveTemplate);
const kotCtrl = require('../controllers/restaurant/kot.controller');
const challanCtrl = require('../controllers/restaurant/challan.controller');

// KOT Endpoints
router.get('/kots/next-no', kotCtrl.getNextKotNo);
router.get('/kots', kotCtrl.listKots);
router.get('/kots/:id', kotCtrl.getKotDetails);
router.post('/kots', kotCtrl.createKot);
router.put('/kots/:id/status', kotCtrl.updateKotStatus);
router.put('/kots/items/:itemId/status', kotCtrl.updateKotItemStatus);
router.put('/kots/:id', kotCtrl.modifyKot);
router.post('/kots/:id/reprint', kotCtrl.reprintKot);

// Delivery Challan Endpoints
router.get('/challans', challanCtrl.listChallans);
router.get('/challans/:id', challanCtrl.getChallanDetails);
router.post('/challans', challanCtrl.createChallan);
router.put('/challans/:id/status', challanCtrl.updateChallanStatus);

module.exports = router;
