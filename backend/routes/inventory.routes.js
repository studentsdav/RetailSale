const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrlprop = require('../controllers/public/propertyInfo.controller');
const itemCtrl = require('../controllers/inventory/itemMaster.controller');
const locationCtrl = require('../controllers/inventory/stockLocation.controller');
const numberingCtrl = require('../controllers/inventory/numberingSettingsV2.controller');
const issueCtrl = require('../controllers/inventory/issue.controller');
const damageCtrl = require('../controllers/inventory/damage.controller');
const returnCtrl = require('../controllers/inventory/return.controller');
const supplierReturnCtrl = require('../controllers/inventory/supplierReturn.controller');
const requestCtrl = require('../controllers/inventory/requestWorkflow.controller');
const supplierCtrl = require('../controllers/supplier/supplierMaster.controller');
const billCtrl = require('../controllers/supplier/supplierPayment.controller');
const settingsctrl = require('../controllers/settings/settings.controller');
const brandingSettingsCtrl = require('../controllers/settings/appBranding.controller');
const groupCtrl = require('../controllers/inventory/group.controller');
const subCtrl = require('../controllers/inventory/subcategory.controller');
const brandCtrl = require('../controllers/inventory/brand.controller');
const backupController = require('../controllers/public/backup.controller');
const syncDatabase = require('../modules/sheetService');

// Public endpoint for recovery flow (no login required).
router.post('/backup/restore-local-enc', backupController.restoreFromLocalEnc);

router.use(auth, license('INVENTORY'));

console.log({
    response: "reached"
})


router.get('/property-info', ctrlprop.getPropertyInfo);
router.post('/property-info', ctrlprop.savePropertyInfo);

// ITEM MASTER
router.get('/items/can-import', itemCtrl.canImportItems);
router.get('/items/can-reset-and-import', itemCtrl.canResetAndImportItems);
router.get('/items/next-code', itemCtrl.getNextItemCode);
router.post('/items', itemCtrl.createItem);
router.get('/items', itemCtrl.getItems);
router.post('/items/bulk-import', itemCtrl.bulkImportItems);
router.delete('/items/delete-all-for-fresh-import', itemCtrl.deleteAllItemsForFreshImport);
router.post('/items/generate-barcodes', itemCtrl.generateBarcodes);
router.post('/items/:id/open-pack', itemCtrl.openPackStock);
router.get('/items/:id', itemCtrl.getItemById);
router.put('/items/:id', itemCtrl.updateItem);
router.delete('/items/:id', itemCtrl.deleteItem);
router.post('/items/:id/image', itemCtrl.uploadItemImage);
router.delete('/items/:id/image', itemCtrl.deleteItemImage);



console.log({
    response: "reached"
})

// SETTINGS
router.get('/settings', settingsctrl.getSettings);
router.post('/settings', settingsctrl.saveSettings);
router.post('/settings/clear-transaction-data', settingsctrl.clearTransactionData);
router.get('/branding', brandingSettingsCtrl.getBranding);
router.post('/branding', brandingSettingsCtrl.saveBranding);
router.get('/status', backupController.getBackupStatusAlert);
router.post('/toggle', backupController.toggleBackup);
router.get('/sync-latest', syncDatabase.syncDatabaseOnly);
router.get('/backup/local-enc', backupController.createLocalEncBackup);

// STOCK LOCATIONS
router.get('/locations/next-code', locationCtrl.getNextLocationCode);
router.post('/locations', locationCtrl.createLocation);
router.get('/locations', locationCtrl.getLocations);
router.get('/locations/:id', locationCtrl.getLocationById);
router.put('/locations/:id', locationCtrl.updateLocation);
router.delete('/locations/:id', locationCtrl.deleteLocation);

// SUPPLIER
router.get('/suppliers/can-import', supplierCtrl.canImportSuppliers);
router.get('/suppliers/next-code', supplierCtrl.getNextSupplierCode);
router.post('/suppliers/bulk-import', supplierCtrl.bulkImportSuppliers);
router.post('/suppliers', supplierCtrl.createSupplier);
router.get('/suppliers', supplierCtrl.getSuppliers);
// router.get('/suppliers/:id', supplierCtrl.getSupplierById);
router.put('/suppliers/:id', supplierCtrl.updateSupplier);
router.delete('/suppliers/:id', supplierCtrl.deleteSupplier);

router.get('/suppliers/bills/list', billCtrl.getSupplierBills);
router.post('/suppliers/bills/pay', billCtrl.paySupplierBill);
router.get('/suppliers/bills/:billId/payments', billCtrl.getBillPayments);

// NUMBERING
router.get('/numbering', numberingCtrl.getSettings);
router.post('/numbering', numberingCtrl.saveSettings);
router.get('/numbering/next', numberingCtrl.getNextNumber);


// ISSUE
router.get('/issue/next-issue-no', issueCtrl.getNextIssueNo);
router.get('/issue/departments', issueCtrl.getDepartments);
router.get('/issue/by-date', issueCtrl.getIssueByDate);
router.get('/issue/:id', issueCtrl.getIssueDetails);
router.put('/issue/:id', issueCtrl.modifyIssue);
router.post('/issue', issueCtrl.createIssue);
router.get('/issue/stock/:itemCode', issueCtrl.getAvailableStock);


router.post('/groups', groupCtrl.create);
router.get('/groups', groupCtrl.getAll);
router.put('/groups/:id', groupCtrl.update);
router.delete('/groups/:id', groupCtrl.delete);

router.post('/subcategories', subCtrl.create);
router.get('/subcategories', subCtrl.getAll);
router.put('/subcategories/:id', subCtrl.update);
router.delete('/subcategories/:id', subCtrl.delete);

router.post('/brands', brandCtrl.create);
router.get('/brands', brandCtrl.getAll);
router.put('/brands/:id', brandCtrl.update);
router.delete('/brands/:id', brandCtrl.delete);



// DAMAGE
router.get('/damage/next-no', damageCtrl.getNextDamageNo);
router.post('/damage', damageCtrl.createDamage);
router.get('/damage/:id', damageCtrl.getDamage);
router.put('/damage/:id/approve', damageCtrl.approveDamage);
router.put('/damage/:id/reject', damageCtrl.rejectDamage);
router.put('/damage/item/:id', damageCtrl.updateDamageItem);
router.delete('/damage/item/:id', damageCtrl.deleteDamageItem);


// RETURNS
router.get('/returns/returned-sum/:issueItemId', returnCtrl.getReturnedQty);
router.get('/returns/indents', returnCtrl.getIndentsByDate);
router.get('/returns/issued-items/:issueId', returnCtrl.getIssuedItems);
router.post('/returns', returnCtrl.saveReturn);
router.put('/returns/item/:id', returnCtrl.updateReturnItem);
router.delete('/returns/item/:id', returnCtrl.deleteReturnItem);


router.put('/returns/:id/cancel', returnCtrl.cancelReturn);

// SUPPLIER RETURNS
router.get('/supplier-returns/grns', supplierReturnCtrl.getGrnsByDate);
router.get('/supplier-returns/received-items/:grnId', supplierReturnCtrl.getReceivedItems);
router.get('/supplier-returns/returned-sum/:receiptItemId', supplierReturnCtrl.getReturnedQty);
router.post('/supplier-returns', supplierReturnCtrl.saveSupplierReturn);
router.get('/supplier-returns', supplierReturnCtrl.listSupplierReturns);
router.get('/supplier-returns/:returnId/refunds', supplierReturnCtrl.getRefunds);
router.post('/supplier-returns/:id/refunds', supplierReturnCtrl.receiveRefund);

// REQUESTS
router.get('/requests/by-date', requestCtrl.getRequestsByDate);


// REQUESTS
router.get('/requests/next-no', requestCtrl.getNextRequestNo);
router.post('/requests', requestCtrl.createRequest);
router.get('/requests', requestCtrl.listRequests);
router.get('/requests/:id', requestCtrl.getRequestDetails);
router.put('/requests/:id/approve', requestCtrl.approveRequest);
router.put('/requests/:id/reject', requestCtrl.rejectRequest);
router.put('/requests/:id/modify', requestCtrl.modifyRequest);
router.put('/requests/:id/cancel', requestCtrl.cancelRequest);



module.exports = router;
