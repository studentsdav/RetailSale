const express = require('express');
const router = express.Router();
const intelligenceController = require('../controllers/intelligence.controller');

// GET /api/v1/intelligence/recommendations?itemIds=1,2&itemCodes=ITEM1,ITEM2
router.get('/recommendations', intelligenceController.getCartRecommendations);

// GET /api/v1/intelligence/customer-insights/:id?phone=9876543210
router.get('/customer-insights/:id', intelligenceController.getCustomerInsights);

module.exports = router;
