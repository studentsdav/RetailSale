const { generateInvoicePdf } = require('../../services/invoicePdf.service');

/**
 * Fetch and stream sales invoice PDF publicly for Meta's servers
 */
async function getInvoicePdfPublic(req, res) {
    try {
        const saleId = Number(req.params.id);
        if (!Number.isInteger(saleId) || saleId <= 0) {
            return res.status(400).send('Invalid Sale ID');
        }

        // Fetch sales header (bypass outlet filter since no user token exists in public fetch)
        const saleHeader = await req.propertyDb.models.sales_headers.findOne({
            where: { id: saleId },
            bypassOutletFilter: true
        });

        if (!saleHeader) {
            return res.status(404).send('Sale not found');
        }

        // Fetch items
        const saleItems = await req.propertyDb.models.sales_items.findAll({
            where: { sale_id: saleId },
            bypassOutletFilter: true
        });

        // Generate PDF
        const pdfBuffer = await generateInvoicePdf(saleHeader, saleItems);

        // Set headers for inline browser PDF viewing / download
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="Invoice_${saleHeader.sale_no.replace(/[^a-zA-Z0-9]/g, '_')}.pdf"`);
        res.setHeader('Content-Length', pdfBuffer.length);

        res.end(pdfBuffer);
    } catch (error) {
        console.error('[PUBLIC SALES PDF ERROR] Generation failed:', error.message);
        res.status(500).send('Failed to generate invoice PDF document');
    }
}

module.exports = {
    getInvoicePdfPublic
};
