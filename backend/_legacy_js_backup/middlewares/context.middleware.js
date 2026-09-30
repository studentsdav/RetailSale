const { contextStorage } = require('../utils/context');

module.exports = {
    contextMiddleware: (req, res, next) => {
        contextStorage.run(new Map(), () => {
            next();
        });
    }
};
