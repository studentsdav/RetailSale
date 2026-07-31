'use strict';
const express = require('express');
const router = express.Router();
const auth = require('../middlewares/auth.middleware');
const propertyContext = require('../middlewares/propertyContext.middleware');
const ctrl = require('../controllers/hrms/hrms.controller');

// All HRMS routes require auth and propertyContext
router.use(auth, propertyContext);

// Masters
router.get('/salary-components', ctrl.getSalaryComponents);
router.post('/salary-components', ctrl.createSalaryComponent);
router.put('/salary-components/:id', ctrl.updateSalaryComponent);
router.delete('/salary-components/:id', ctrl.deleteSalaryComponent);

router.get('/pay-structures', ctrl.getPayStructures);
router.post('/pay-structures', ctrl.createPayStructure);
router.put('/pay-structures/:id', ctrl.updatePayStructure);
router.delete('/pay-structures/:id', ctrl.deletePayStructure);

router.get('/leave-types', ctrl.getLeaveTypes);
router.post('/leave-types', ctrl.createLeaveType);
router.put('/leave-types/:id', ctrl.updateLeaveType);
router.delete('/leave-types/:id', ctrl.deleteLeaveType);

router.get('/shifts', ctrl.getShifts);
router.post('/shifts', ctrl.createShift);
router.put('/shifts/:id', ctrl.updateShift);
router.delete('/shifts/:id', ctrl.deleteShift);

router.get('/designations', ctrl.getDesignations);
router.post('/designations', ctrl.createDesignation);
router.put('/designations/:id', ctrl.updateDesignation);
router.delete('/designations/:id', ctrl.deleteDesignation);

// Employees
router.get('/employees', ctrl.getEmployees);
router.get('/employees/next-code', ctrl.getNextEmployeeCode);
router.get('/employees/:id', ctrl.getEmployee);
router.post('/employees', ctrl.createEmployee);
router.put('/employees/:id', ctrl.updateEmployee);
router.post('/employees/:id/terminate', ctrl.terminateEmployee);
router.post('/employees/:id/revise-salary', ctrl.reviseSalary);
router.post('/employees/:id/bonus', ctrl.addBonus);
router.get('/employees/:id/revisions', ctrl.getEmployeeRevisions);
router.get('/employees/:id/bonuses', ctrl.getEmployeeBonuses);
router.get('/employees/:id/commissions', ctrl.getEmployeeCommissions);

// Attendance
router.get('/attendance', ctrl.getAttendance);
router.post('/attendance/punch-in', ctrl.punchIn);
router.post('/attendance/punch-out', ctrl.punchOut);
router.post('/attendance/manual', ctrl.manualAttendance);

// Leaves
router.get('/leaves', ctrl.getLeaves);
router.post('/leaves', ctrl.applyLeave);
router.put('/leaves/:id/approve', ctrl.approveLeave);
router.put('/leaves/:id/reject', ctrl.rejectLeave);

// Loans
router.get('/loans', ctrl.getLoans);
router.post('/loans', ctrl.createLoan);
router.put('/loans/:id/status', ctrl.updateLoanStatus);

// Payroll
router.get('/payroll/settings', ctrl.getPayrollSettings);
router.post('/payroll/settings', ctrl.savePayrollSettings);
router.post('/payroll/preview', ctrl.previewPayroll);
router.post('/payroll/run', ctrl.runPayroll);
router.post('/payroll/bulk-revise', ctrl.bulkRevise);
router.post('/payroll/bulk-bonus', ctrl.bulkBonus);
router.get('/payroll/revisions', ctrl.getRevisions);
router.get('/payroll/bonuses', ctrl.getBonuses);
router.get('/payroll/approvals', ctrl.getApprovals);
router.put('/payroll/revisions/:id/approve', ctrl.approveRevision);
router.put('/payroll/revisions/:id/reject', ctrl.rejectRevision);
router.put('/payroll/bonuses/:id/approve', ctrl.approveBonus);
router.put('/payroll/bonuses/:id/reject', ctrl.rejectBonus);
router.post('/payroll/details/pay', ctrl.payPayrollDetails);
router.post('/payroll/details/:id/toggle-hold', ctrl.togglePayrollDetailHold);
router.post('/payroll/:id/approve', ctrl.approvePayroll);
router.get('/payroll/history', ctrl.getPayrollHistory);
router.get('/payroll/:id/payslip/:employeeId', ctrl.getPayslip);
router.get('/payroll/dashboard-stats', ctrl.getPayrollDashboardStats);

// Cashier Handover
router.post('/handover', ctrl.createHandover);
router.get('/handovers', ctrl.getHandovers);

// Holidays
router.get('/holidays', ctrl.getHolidays);
router.post('/holidays', ctrl.createHoliday);
router.delete('/holidays/:id', ctrl.deleteHoliday);
router.post('/attendance/auto-weekly-offs', ctrl.autoWeeklyOffs);

module.exports = router;
