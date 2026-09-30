import { request } from '../utils/whatsappHelper';

const META_BASE_URL = 'https://graph.facebook.com/v20.0';

/**
 * Validate integration settings by sending a simple text test message
 */
export async function testConnection(phoneNumberId: string, token: string, testNumber: string): Promise<any> {
    const url = `${META_BASE_URL}/${phoneNumberId}/messages`;
    const headers = {
        'Authorization': `Bearer ${token}`
    };
    const body = {
        messaging_product: 'whatsapp',
        to: testNumber,
        type: 'text',
        text: {
            body: 'Hello! This is a test message to verify your WhatsApp API integration credentials.'
        }
    };

    const response: any = await request('POST', url, headers, body);
    if (response.statusCode >= 300) {
        throw new Error(response.body?.error?.message || `API error (${response.statusCode})`);
    }
    return response.body;
}

/**
 * Sync templates from Meta Business Account API
 */
export async function syncTemplatesFromMeta(wabaId: string, token: string): Promise<any[]> {
    const url = `${META_BASE_URL}/${wabaId}/message_templates?limit=100`;
    const headers = {
        'Authorization': `Bearer ${token}`
    };

    const response: any = await request('GET', url, headers);
    if (response.statusCode >= 300) {
        throw new Error(response.body?.error?.message || `API error (${response.statusCode})`);
    }
    return response.body?.data || [];
}

/**
 * Submit a template creation payload to Meta for approval
 */
export async function submitTemplateToMeta(wabaId: string, token: string, templateData: any): Promise<any> {
    const url = `${META_BASE_URL}/${wabaId}/message_templates`;
    const headers = {
        'Authorization': `Bearer ${token}`
    };

    const components: any[] = [];

    // 1. Header Component
    if (templateData.header_type && templateData.header_type !== 'NONE') {
        const header: any = {
            type: 'HEADER',
            format: templateData.header_type.toUpperCase()
        };
        if (templateData.header_type === 'TEXT' && templateData.header_text) {
            header.text = templateData.header_text;
        }
        components.push(header);
    }

    // 2. Body Component (Required)
    const bodyComp: any = {
        type: 'BODY',
        text: templateData.body_text
    };
    if (templateData.body_text_examples && Array.isArray(templateData.body_text_examples) && templateData.body_text_examples.length > 0) {
        bodyComp.example = {
            body_text: [templateData.body_text_examples]
        };
    }
    components.push(bodyComp);

    // 3. Footer Component
    if (templateData.footer_text) {
        components.push({
            type: 'FOOTER',
            text: templateData.footer_text
        });
    }

    // 4. Buttons Component
    if (templateData.buttons && Array.isArray(templateData.buttons) && templateData.buttons.length > 0) {
        components.push({
            type: 'BUTTONS',
            buttons: templateData.buttons
        });
    }

    const body = {
        name: templateData.template_name,
        category: templateData.category.toUpperCase(), // UTILITY, MARKETING
        language: templateData.language,
        components
    };

    const response: any = await request('POST', url, headers, body);
    if (response.statusCode >= 300) {
        console.error('[META API ERROR BODY]:', JSON.stringify(response.body));
        const errMsg = response.body?.error?.message || `API error (${response.statusCode})`;
        const details = response.body?.error?.error_data?.details || response.body?.error?.error_user_msg || '';
        throw new Error(details ? `${errMsg} (${details})` : errMsg);
    }
    return response.body;
}

/**
 * Dispatch a message using Meta Cloud API
 */
export async function sendMessage(phoneNumberId: string, token: string, payload: any): Promise<any> {
    const url = `${META_BASE_URL}/${phoneNumberId}/messages`;
    const headers = {
        'Authorization': `Bearer ${token}`
    };

    const response: any = await request('POST', url, headers, payload);
    if (response.statusCode >= 300) {
        throw new Error(response.body?.error?.message || `API error (${response.statusCode})`);
    }
    return response.body;
}

export async function deleteTemplateFromMeta(wabaId: string, token: string, templateName: string): Promise<any> {
    const url = `${META_BASE_URL}/${wabaId}/message_templates?name=${templateName}`;
    const headers = {
        'Authorization': `Bearer ${token}`
    };

    const response: any = await request('DELETE', url, headers);
    if (response.statusCode >= 300) {
        throw new Error(response.body?.error?.message || `API error (${response.statusCode})`);
    }
    return response.body;
}

export default {
    testConnection,
    syncTemplatesFromMeta,
    submitTemplateToMeta,
    sendMessage,
    deleteTemplateFromMeta
};
