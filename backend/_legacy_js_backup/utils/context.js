const { AsyncLocalStorage } = require('async_hooks');

const contextStorage = new AsyncLocalStorage();

module.exports = {
    contextStorage
};
