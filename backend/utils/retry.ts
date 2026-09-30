export async function retry<T>(fn: () => Promise<T>, retries: number = 3, delay: number = 3000): Promise<T> {
    let attempt = 0;

    while (attempt < retries) {
        try {
            return await fn();
        } catch (err) {
            attempt++;

            console.log(`❌ Attempt ${attempt} failed`);

            if (attempt >= retries) throw err;

            await new Promise(res => setTimeout(res, delay));
        }
    }
    throw new Error('Retry limit reached');
}

export default { retry };
