const cron = require("node-cron");
const { createNotification } = require("../routes/notifications");

module.exports = function (db) {

  async function checkEmployees(level) {

    try {

      const today = new Date().toISOString().slice(0, 10);

      // All Active Employees
      const [employees] = await db.query(`
        SELECT full_name
        FROM employees
        WHERE status='Active'
      `);

      for (const emp of employees) {

        const employee = emp.full_name;

        // Did employee submit today's planner?
        const [planner] = await db.query(
          `
          SELECT id
          FROM day_planner
          WHERE employee_name=?
          AND DATE(created_at)=?
          LIMIT 1
          `,
          [employee, today]
        );

        if (planner.length > 0) continue;

        //-----------------------------------------------------
        // 9:15 Reminder
        //-----------------------------------------------------

        if (level == "REMINDER") {

          await createNotification({

            senderName: "Admin",

            recipientName: employee,

            message: JSON.stringify({

              preview:
                  "Reminder: Submit today's Day Planner before work begins.",

              payload:{

                type:"DAY_PLANNER_REMINDER",

                level:"REMINDER"

              }

            })

          });

        }

        //-----------------------------------------------------
        // 9:30 Alert
        //-----------------------------------------------------

        if (level == "ALERT") {

          await createNotification({

            senderName:"Admin",

            recipientName:employee,

            message:JSON.stringify({

              preview:
                "Alert: Your Day Planner has still not been submitted.",

              payload:{

                type:"DAY_PLANNER_ALERT",

                level:"ALERT"

              }

            })

          });

        }

        //-----------------------------------------------------
        //10:00 Warning
        //-----------------------------------------------------

        if(level=="WARNING"){

          // Employee

          await createNotification({

            senderName:"Admin",

            recipientName:employee,

            message:JSON.stringify({

              preview:
                  "Warning: Day Planner not submitted even after 10:00 AM.",

              payload:{

                type:"DAY_PLANNER_WARNING",

                level:"WARNING"

              }

            })

          });

          //--------------------------------------------------
          // Admin Notification
          //--------------------------------------------------

          await createNotification({

            senderName:"System",

            recipientName:"Admin",

            message:JSON.stringify({

              preview:
                `${employee} has NOT submitted today's Day Planner.`,

              payload:{

                type:"DAY_PLANNER_ADMIN_WARNING",

                employee

              }

            })

          });

        }

      }

    }

    catch(err){

      console.log(err);

    }

  }

  //----------------------------------------------------------
  //9:15
  //----------------------------------------------------------

  cron.schedule("15 9 * * *", () => {

    console.log("Checking Reminder");

    checkEmployees("REMINDER");

  },{

    timezone:"Asia/Kolkata"

  });

  //----------------------------------------------------------
  //9:30
  //----------------------------------------------------------

  cron.schedule("30 9 * * *", () => {

    console.log("Checking Alert");

    checkEmployees("ALERT");

  },{

    timezone:"Asia/Kolkata"

  });

  //----------------------------------------------------------
  //10:00
  //----------------------------------------------------------

  cron.schedule("0 10 * * *", () => {

    console.log("Checking Warning");

    checkEmployees("WARNING");

  },{

    timezone:"Asia/Kolkata"

  });

};