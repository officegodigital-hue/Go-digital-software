const express = require('express');

const router = express.Router();


const authController =
require('../controllers/auth.controller');


const authMiddleware =
require('../middlewares/auth.middleware');


console.log(
    "AUTH CONTROLLER:",
    authController
);


console.log(
    "AUTH MIDDLEWARE:",
    authMiddleware
);



router.post(
    '/login',
    authController.login
);


router.get(
    '/me',
    authMiddleware.authenticate,
    authController.getCurrentUser
);



module.exports = router;