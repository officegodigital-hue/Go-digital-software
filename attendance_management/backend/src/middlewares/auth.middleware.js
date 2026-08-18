const jwt = require('jsonwebtoken');

const AppError = require('../utils/AppError');



const authenticate = (req, res, next) => {

    const authorization =
        req.headers.authorization;


    if (
        !authorization ||
        !authorization.startsWith('Bearer ')
    ) {

        return next(
            new AppError(
                401,
                'UNAUTHORIZED',
                'Authentication token is required'
            )
        );

    }


    const token =
        authorization
        .substring(7)
        .trim();



    if (!token) {

        return next(
            new AppError(
                401,
                'UNAUTHORIZED',
                'Authentication token is required'
            )
        );

    }



    try {


        const decoded =
            jwt.verify(
                token,
                process.env.JWT_ACCESS_SECRET
            );



        req.auth = {

            ...decoded,


            userId:
                decoded.userId ??
                decoded.user_id ??
                null,


            employeeId:
                decoded.employeeId ??
                decoded.employee_id ??
                null,


            companyId:
                decoded.companyId ??
                decoded.company_id ??
                null,


            branchId:
                decoded.branchId ??
                decoded.branch_id ??
                null,


            role:
                decoded.role ??
                null,


            isStaticAdmin:
                decoded.isStaticAdmin === true

        };



        next();



    } catch(error) {


        if(error.name === 'TokenExpiredError') {

            return next(
                new AppError(
                    401,
                    'TOKEN_EXPIRED',
                    'Authentication token has expired'
                )
            );

        }


        return next(
            new AppError(
                401,
                'TOKEN_INVALID',
                'Authentication token is invalid'
            )
        );


    }

};






const authorizeRoles = (...allowedRoles) => {


    return (req,res,next)=>{


        const role =
            req.auth?.role;



        if(!role){

            return next(
                new AppError(
                    403,
                    'ROLE_NOT_FOUND',
                    'User role was not found'
                )
            );

        }



        const currentRole =
            String(role).toLowerCase();



        const allowed =
            allowedRoles.map(
                item =>
                String(item).toLowerCase()
            );



        if(!allowed.includes(currentRole)){


            return next(
                new AppError(
                    403,
                    'FORBIDDEN',
                    'You do not have permission'
                )
            );


        }



        next();


    };


};






const requireCompany = (req,res,next)=>{


    // Static admin allowed
    if(req.auth?.isStaticAdmin){

        return next();

    }



    if(!req.auth?.companyId){


        return next(
            new AppError(
                403,
                'COMPANY_REQUIRED',
                'Company information missing'
            )
        );


    }


    next();

};






const requireEmployee = (req,res,next)=>{


    // Static admin allowed
    if(req.auth?.isStaticAdmin){

        return next();

    }



    if(!req.auth?.employeeId){


        return next(
            new AppError(
                403,
                'EMPLOYEE_REQUIRED',
                'Employee information missing'
            )
        );


    }


    next();


};






module.exports = {

    authenticate,

    authorizeRoles,

    requireCompany,

    requireEmployee

};