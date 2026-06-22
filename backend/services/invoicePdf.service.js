const PDFDocument = require('pdfkit');

/**
 * Generate a beautifully formatted PDF invoice using pdfkit
 * @param {object} saleHeader Sales Header record
 * @param {array} saleItems Sales Items list
 * @returns {Promise<Buffer>} Generated PDF bytes buffer
 */
function generateInvoicePdf(saleHeader, saleItems) {
    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({ size: 'A4', margin: 40 });
            const buffers = [];

            doc.on('data', buffers.push.bind(buffers));
            doc.on('end', () => {
                const pdfData = Buffer.concat(buffers);
                resolve(pdfData);
            });

            // ---------------- HEADER / LOGO ----------------
            doc.fillColor('#1e3a8a').fontSize(22).font('Helvetica-Bold').text('INVOICE', { align: 'right' });
            doc.fillColor('#4b5563').fontSize(10).font('Helvetica').text('Retail Store POS Alert Engine', { align: 'right' });
            doc.moveDown(1.5);

            // ---------------- SENDER / RECEIVER ----------------
            const startY = doc.y;
            doc.fillColor('#1f2937').fontSize(11).font('Helvetica-Bold').text('Billed From:', 40, startY);
            doc.font('Helvetica').fontSize(10).text(`Outlet ID: ${saleHeader.outlet_id}`);
            doc.text(`Billing Country: ${saleHeader.billing_country || 'India'}`);

            doc.font('Helvetica-Bold').fontSize(11).text('Billed To:', 280, startY);
            doc.font('Helvetica').fontSize(10).text(`Customer: ${saleHeader.customer_name || 'Walk-in Customer'}`);
            if (saleHeader.customer_phone) {
                doc.text(`Phone: ${saleHeader.customer_phone}`, 280);
            }
            if (saleHeader.customer_gstin) {
                doc.text(`GSTIN: ${saleHeader.customer_gstin}`, 280);
            }

            doc.moveDown(2);

            // ---------------- TRANSACTION DETAILS ----------------
            const detailsY = doc.y;
            doc.font('Helvetica-Bold').text('Transaction Details:', 40, detailsY);
            doc.font('Helvetica').text(`Invoice Number: ${saleHeader.sale_no}`);
            doc.text(`Invoice Date: ${new Date(saleHeader.sale_date).toLocaleDateString()}`);
            doc.text(`Payment Mode: ${saleHeader.payment_mode || 'Cash'}`);

            doc.moveDown(2);

            // ---------------- ITEMS TABLE ----------------
            let currentY = doc.y;
            
            // Header Row
            doc.rect(40, currentY, 515, 20).fill('#1e3a8a');
            doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(10);
            doc.text('Item Name', 50, currentY + 5, { width: 220 });
            doc.text('Qty', 280, currentY + 5, { width: 60, align: 'right' });
            doc.text('Rate', 350, currentY + 5, { width: 80, align: 'right' });
            doc.text('Total', 440, currentY + 5, { width: 100, align: 'right' });

            currentY += 20;

            // Data Rows
            doc.fillColor('#374151').font('Helvetica').fontSize(10);
            let index = 0;
            for (const item of saleItems) {
                // Alternating backgrounds
                if (index % 2 === 1) {
                    doc.rect(40, currentY, 515, 20).fill('#f3f4f6');
                    doc.fillColor('#374151');
                }
                
                doc.text(item.item_name || 'Item', 50, currentY + 5, { width: 220 });
                doc.text(Number(item.qty).toFixed(2), 280, currentY + 5, { width: 60, align: 'right' });
                doc.text(Number(item.rate).toFixed(2), 350, currentY + 5, { width: 80, align: 'right' });
                doc.text(Number(item.line_total).toFixed(2), 440, currentY + 5, { width: 100, align: 'right' });
                
                currentY += 20;
                index++;
            }

            doc.moveDown(1.5);

            // ---------------- TOTALS SECTION ----------------
            const totalY = doc.y;
            doc.rect(340, totalY, 215, 60).fill('#f9fafb');
            doc.fillColor('#111827').font('Helvetica-Bold');
            
            doc.text('Subtotal:', 350, totalY + 10);
            doc.text(Number(saleHeader.sub_total || saleHeader.amount || saleHeader.net_amount).toFixed(2), 450, totalY + 10, { align: 'right', width: 90 });

            doc.fontSize(12).fillColor('#10b981');
            doc.text('Net Total:', 350, totalY + 35);
            doc.text(Number(saleHeader.net_amount).toFixed(2), 450, totalY + 35, { align: 'right', width: 90 });

            // ---------------- FOOTER ----------------
            doc.fillColor('#9ca3af').fontSize(8).font('Helvetica').text('Thank you for shopping with us! This is an automated system-generated billing record.', 40, doc.page.height - 50, { align: 'center', width: 515 });

            doc.end();
        } catch (e) {
            reject(e);
        }
    });
}

module.exports = {
    generateInvoicePdf
};
