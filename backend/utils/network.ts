import dns from 'dns';

export function isOnline(): Promise<boolean> {
    return new Promise((resolve) => {
        dns.lookup("google.com", (err) => {
            resolve(!err);
        });
    });
}

export default { isOnline };
