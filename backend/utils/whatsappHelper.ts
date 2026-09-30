import https from 'https';

/**
 * Standard https request wrapper
 * @param method HTTP method (GET, POST, etc.)
 * @param url Meta API url path/query (e.g. /v20.0/messages)
 * @param headers Request headers
 * @param body Payload object
 */
export function request(method: string, url: string, headers: any = {}, body: any = null): Promise<{ statusCode?: number; body: any }> {
    return new Promise((resolve, reject) => {
        const parsedUrl = new URL(url);
        
        const options = {
            method: method.toUpperCase(),
            hostname: parsedUrl.hostname,
            port: parsedUrl.port || 443,
            path: parsedUrl.pathname + parsedUrl.search,
            headers: {
                'Content-Type': 'application/json',
                ...headers
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    resolve({ statusCode: res.statusCode, body: parsed });
                } catch (e) {
                    resolve({ statusCode: res.statusCode, body: data });
                }
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        if (body && (method === 'POST' || method === 'PUT')) {
            req.write(JSON.stringify(body));
        }
        
        req.end();
    });
}

export default {
    request
};
