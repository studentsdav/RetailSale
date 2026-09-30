const router = require('express').Router();
const auth = require('../middlewares/auth.middleware');
const license = require('../middlewares/license.middleware');
const ctrl = require('../controllers/delivery/delivery.controller');

const adminAuth = [auth, license('INVENTORY')];

// Customer app endpoints (accessible from Customer App)
router.get('/catalog', ctrl.listCatalogProducts);
router.post('/orders', ctrl.placeOrder);
router.get('/orders/:id/track', ctrl.trackOrder);
router.post('/customer/register', ctrl.registerCustomer);
router.post('/customer/login', ctrl.loginCustomer);
router.post('/customer/forgot-password/request-otp', ctrl.requestCustomerOtp);
router.post('/customer/forgot-password/reset', ctrl.resetCustomerPassword);
router.get('/customer/history', ctrl.getCustomerHistory);
router.post('/orders/:id/return', ctrl.requestOrderReturn);
router.post('/orders/:id/cancel', ctrl.cancelOrderAsCustomer);
router.post('/orders/:id/feedback', ctrl.submitOrderFeedback);
router.get('/customer/notifications', ctrl.getCustomerNotifications);
router.get('/sales/:id', ctrl.getSaleDetailsPublic);

// Rider app endpoints (accessible from Rider App)
router.post('/rider/register', ctrl.registerRiderFromApp);
router.post('/rider/login', ctrl.loginRider);
router.put('/rider/orders/:id/status', ctrl.updateOrderDeliveryStatus);
router.put('/rider/orders/:id/handover-return', ctrl.handoverReturn);
router.put('/rider/status', ctrl.updateRiderStatus);
router.get('/rider/notifications', ctrl.getRiderNotifications);

// Retailer dashboard endpoints (Require admin auth and inventory license)
router.get('/retailer/orders', adminAuth, ctrl.listOrders);
router.get('/retailer/riders', adminAuth, ctrl.listRiders);
router.post('/retailer/riders', adminAuth, ctrl.registerRider);
router.delete('/retailer/riders/:id', adminAuth, ctrl.deleteRider);
router.put('/retailer/riders/:id/reset-password', adminAuth, ctrl.resetRiderPassword);
router.post('/retailer/orders/:id/accept', adminAuth, ctrl.acceptOrder);
router.post('/retailer/orders/:id/reassign', adminAuth, ctrl.reassignOrder);
router.post('/retailer/orders/:id/cancel', adminAuth, ctrl.cancelOrder);
router.post('/retailer/orders/:id/accept-return', adminAuth, ctrl.acceptOrderReturn);
router.post('/retailer/orders/:id/final-receive-return', adminAuth, ctrl.finalReceiveReturn);
router.post('/retailer/orders/:id/mark-refund-paid', adminAuth, ctrl.markRefundPaid);
router.post('/retailer/orders/:id/feedback/reply', adminAuth, ctrl.replyToOrderFeedback);
router.post('/retailer/riders/:id/pay-commission', adminAuth, ctrl.payRiderCommission);
router.put('/retailer/items/:item_code/b2b-rate', adminAuth, ctrl.updateB2bRate);
router.get('/retailer/return-settings', ctrl.getReturnSettings);
router.put('/retailer/return-settings', adminAuth, ctrl.updateReturnSettings);
router.put('/retailer/items/:item_code/return-window', adminAuth, ctrl.updateItemReturnWindow);
router.get('/retailer/transactions', adminAuth, ctrl.listTransactions);
router.post('/retailer/orders/:id/refund-gateway', adminAuth, ctrl.refundGatewayPayment);
router.get('/retailer/orders/:id/pending-refunds', adminAuth, ctrl.getOrderPendingRefunds);
router.post('/retailer/orders/:id/refund-via-creditnote', adminAuth, ctrl.refundGatewayViaCreditNote);


module.exports = router;
