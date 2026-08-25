'use strict';
const { Op } = require('sequelize');
const moment = require('moment');

function evalFormula(formula, baseSalary, basic) {
  if (!formula) return 0;
  try {
    let f = formula.toLowerCase()
      .replace(/basic/g, String(basic))
      .replace(/base_salary/g, String(baseSalary))
      .replace(/base/g, String(baseSalary))
      .replace(/\s+/g, '');
    
    if (/^[0-9.+\-*/()]+$/.test(f)) {
      return parseFloat(Function(`"use strict"; return (${f})`)()) || 0;
    }
    return 0;
  } catch (err) {
    console.error("Formula eval error:", err);
    return 0;
  }
}

// ==================== MASTERS ====================

exports.getSalaryComponents = async (req, res) => {
  try {
    const { hr_salary_components } = req.propertyDb.models;
    const data = await hr_salary_components.findAll({ where: { outlet_id: req.user.outlet_id } });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createSalaryComponent = async (req, res) => {
  try {
    const { hr_salary_components } = req.propertyDb.models;
    const data = await hr_salary_components.create({
      ...req.body,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateSalaryComponent = async (req, res) => {
  try {
    const { hr_salary_components } = req.propertyDb.models;
    const [updated] = await hr_salary_components.update(req.body, {
      where: { id: req.params.id, outlet_id: req.user.outlet_id }
    });
    if (!updated) return res.status(404).json({ success: false, message: 'Not found' });
    const data = await hr_salary_components.findByPk(req.params.id);
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getPayStructures = async (req, res) => {
  try {
    const { hr_pay_structures, hr_salary_components } = req.propertyDb.models;
    const data = await hr_pay_structures.findAll({
      where: { outlet_id: req.user.outlet_id },
      include: [{
        model: hr_salary_components,
        as: 'components',
        through: { attributes: [] }
      }]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createPayStructure = async (req, res) => {
  try {
    const { hr_pay_structures, hr_pay_structure_components, hr_salary_components } = req.propertyDb.models;
    const { name, description, is_active, componentIds } = req.body;
    const structure = await hr_pay_structures.create({
      name,
      description: description || null,
      is_active: is_active !== false,
      outlet_id: req.user.outlet_id
    });

    // Attach any pre-selected component IDs
    if (Array.isArray(componentIds) && componentIds.length > 0) {
      await hr_pay_structure_components.bulkCreate(
        componentIds.map(cId => ({ pay_structure_id: structure.id, salary_component_id: cId }))
      );
    }

    // Return the plain created record (avoids join errors on fresh DB)
    return res.json({ success: true, data: structure.toJSON() });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};



exports.getLeaveTypes = async (req, res) => {
  try {
    const { hr_leave_types } = req.propertyDb.models;
    const data = await hr_leave_types.findAll({ where: { outlet_id: req.user.outlet_id } });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createLeaveType = async (req, res) => {
  try {
    const { hr_leave_types } = req.propertyDb.models;
    const data = await hr_leave_types.create({
      ...req.body,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getShifts = async (req, res) => {
  try {
    const { hr_shifts } = req.propertyDb.models;
    const data = await hr_shifts.findAll({ where: { outlet_id: req.user.outlet_id } });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createShift = async (req, res) => {
  try {
    const { hr_shifts } = req.propertyDb.models;
    const data = await hr_shifts.create({
      name: req.body.name,
      start_time: req.body.start_time,
      end_time: req.body.end_time,
      grace_period_mins: req.body.grace_period_mins ?? 15,
      weekly_offs: req.body.weekly_offs ?? ["Sunday"],
      outlet_id: req.user.outlet_id
    });
    return res.json({ success: true, data: data.toJSON() });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};


exports.getDesignations = async (req, res) => {
  try {
    const { hr_designations } = req.propertyDb.models;
    const data = await hr_designations.findAll({ where: { outlet_id: req.user.outlet_id } });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createDesignation = async (req, res) => {
  try {
    const { hr_designations } = req.propertyDb.models;
    const data = await hr_designations.create({
      name: req.body.name,
      outlet_id: req.user.outlet_id
    });
    return res.json({ success: true, data: data.toJSON() });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};


// ==================== EMPLOYEES ====================

exports.getEmployees = async (req, res) => {
  try {
    const { hr_employees, hr_designations, hr_shifts, hr_pay_structures, hr_leave_balances } = req.propertyDb.models;
    const { status, designation_id } = req.query;
    
    const where = { outlet_id: req.user.outlet_id };
    if (status) where.status = status;
    if (designation_id) where.designation_id = designation_id;

    const data = await hr_employees.findAll({
      where,
      include: [
        { model: hr_designations, as: 'designation' },
        { model: hr_shifts, as: 'shift' },
        { model: hr_pay_structures, as: 'payStructure' },
        { model: hr_leave_balances, as: 'leaveBalances', include: ['leaveType'] }
      ]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getEmployee = async (req, res) => {
  try {
    const { hr_employees, hr_designations, hr_shifts, hr_pay_structures, hr_leave_balances } = req.propertyDb.models;
    const data = await hr_employees.findOne({
      where: { id: req.params.id, outlet_id: req.user.outlet_id },
      include: [
        { model: hr_designations, as: 'designation' },
        { model: hr_shifts, as: 'shift' },
        { model: hr_pay_structures, as: 'payStructure' },
        { model: hr_leave_balances, as: 'leaveBalances', include: ['leaveType'] }
      ]
    });
    if (!data) return res.status(404).json({ success: false, message: 'Employee not found' });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getEmployeeCommissions = async (req, res) => {
  try {
    const { hr_sales_commissions, sales_headers } = req.propertyDb.models;
    const commissions = await hr_sales_commissions.findAll({
      where: { employee_id: req.params.id, outlet_id: req.user.outlet_id },
      include: [{ model: sales_headers, as: 'sale', attributes: ['id', 'sale_no', 'net_amount'] }],
      order: [['id', 'DESC']]
    });
    return res.json({ success: true, data: commissions });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getNextEmployeeCode = async (req, res) => {
  try {
    const { hr_employees } = req.propertyDb.models;
    const allEmps = await hr_employees.findAll({
      where: {
        outlet_id: req.user.outlet_id,
        employee_code: { [Op.like]: 'EMP-%' }
      },
      attributes: ['employee_code']
    });
    
    let maxNum = 0;
    for (const e of allEmps) {
      const match = e.employee_code.match(/EMP-(\d+)/i);
      if (match) {
        const num = parseInt(match[1]);
        if (num > maxNum) {
          maxNum = num;
        }
      }
    }
    const nextCode = `EMP-${String(maxNum + 1).padStart(4, '0')}`;
    return res.json({ success: true, code: nextCode });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createEmployee = async (req, res) => {
  try {
    const { hr_employees, hr_leave_balances, hr_leave_types, hr_salary_components } = req.propertyDb.models;
    const { leave_quotas, ...employeeData } = req.body;

    // Check if salary components exist in master
    const compsCount = await hr_salary_components.count({
      where: { outlet_id: req.user.outlet_id, is_active: true }
    });
    if (compsCount === 0) {
      return res.status(400).json({ success: false, message: 'First add salary components from master before adding an employee.' });
    }

    // Auto-generate employee code if left blank
    let empCode = employeeData.employee_code;
    if (!empCode || empCode.trim() === '') {
      const allEmps = await hr_employees.findAll({
        where: {
          outlet_id: req.user.outlet_id,
          employee_code: { [Op.like]: 'EMP-%' }
        },
        attributes: ['employee_code']
      });
      
      let maxNum = 0;
      for (const e of allEmps) {
        const match = e.employee_code.match(/EMP-(\d+)/i);
        if (match) {
          const num = parseInt(match[1]);
          if (num > maxNum) {
            maxNum = num;
          }
        }
      }
      empCode = `EMP-${String(maxNum + 1).padStart(4, '0')}`;
    } else {
      empCode = empCode.trim();
    }

    // Check if employee code already exists for this outlet
    const existing = await hr_employees.findOne({
      where: { employee_code: empCode, outlet_id: req.user.outlet_id }
    });
    if (existing) {
      return res.status(400).json({ success: false, message: `Employee code '${empCode}' is already in use by another employee.` });
    }

    const employee = await hr_employees.create({
      ...employeeData,
      employee_code: empCode,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });

    const leaveTypes = await hr_leave_types.findAll({
      where: { is_active: true, outlet_id: req.user.outlet_id }
    });

    const currentYear = new Date().getFullYear();
    const balances = leaveTypes.map(lt => {
      let quota = lt.annual_quota || 0;
      if (leave_quotas && leave_quotas[lt.id.toString()] !== undefined) {
        quota = parseFloat(leave_quotas[lt.id.toString()]) || 0;
      }
      return {
        employee_id: employee.id,
        leave_type_id: lt.id,
        year: currentYear,
        allocated_quota: quota,
        used_quota: 0.0,
        outlet_id: req.user.outlet_id,
        created_by: req.user.id
      };
    });

    if (balances.length > 0) {
      await hr_leave_balances.bulkCreate(balances);
    }

    return res.json({ success: true, data: employee });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateEmployee = async (req, res) => {
  try {
    const { hr_employees, hr_leave_balances } = req.propertyDb.models;
    const { leave_quotas, ...employeeData } = req.body;

    if (employeeData.employee_code) {
      const existing = await hr_employees.findOne({
        where: {
          employee_code: employeeData.employee_code.trim(),
          outlet_id: req.user.outlet_id,
          id: { [Op.ne]: req.params.id }
        }
      });
      if (existing) {
        return res.status(400).json({ success: false, message: `Employee code '${employeeData.employee_code}' is already in use by another employee.` });
      }
    }

    const [updated] = await hr_employees.update(employeeData, {
      where: { id: req.params.id, outlet_id: req.user.outlet_id }
    });
    if (!updated) return res.status(404).json({ success: false, message: 'Not found' });

    if (leave_quotas) {
      const currentYear = new Date().getFullYear();
      for (const [ltIdStr, quotaVal] of Object.entries(leave_quotas)) {
        const ltId = parseInt(ltIdStr);
        const quota = parseFloat(quotaVal) || 0;

        const [balance, created] = await hr_leave_balances.findOrCreate({
          where: {
            employee_id: req.params.id,
            leave_type_id: ltId,
            year: currentYear,
            outlet_id: req.user.outlet_id
          },
          defaults: {
            allocated_quota: quota,
            used_quota: 0.0,
            outlet_id: req.user.outlet_id,
            created_by: req.user.id
          }
        });

        if (!created) {
          balance.allocated_quota = quota;
          await balance.save();
        }
      }
    }

    const data = await hr_employees.findByPk(req.params.id);
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.terminateEmployee = async (req, res) => {
  try {
    const { hr_employees } = req.propertyDb.models;
    const { terminated_date, termination_reason } = req.body;
    const [updated] = await hr_employees.update({
      status: 'Terminated',
      terminated_date,
      termination_reason
    }, {
      where: { id: req.params.id, outlet_id: req.user.outlet_id }
    });
    if (!updated) return res.status(404).json({ success: false, message: 'Not found' });
    return res.json({ success: true, message: 'Employee terminated' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== ATTENDANCE ====================

async function recalculateLeaveBalances(employeeId, outletId, propertyDb) {
  try {
    const { hr_leave_balances, hr_leave_applications, hr_attendance_punches, hr_leave_types } = propertyDb.models;
    const currentYear = new Date().getFullYear();
    
    // Load all active leave types to ensure balances exist for each of them
    const leaveTypes = await hr_leave_types.findAll({
      where: { is_active: true, outlet_id: outletId }
    });

    for (const lt of leaveTypes) {
      // Find or create the balance record for this leave type
      const [bal, created] = await hr_leave_balances.findOrCreate({
        where: {
          employee_id: employeeId,
          leave_type_id: lt.id,
          year: currentYear,
          outlet_id: outletId
        },
        defaults: {
          allocated_quota: lt.annual_quota || 14,
          used_quota: 0.0,
          created_by: null
        }
      });

      let appDays = 0;
      if (hr_leave_applications) {
        const apps = await hr_leave_applications.findAll({
          where: {
            employee_id: employeeId,
            leave_type_id: lt.id,
            status: 'Approved',
            outlet_id: outletId
          }
        });
        appDays = apps.reduce((sum, a) => sum + parseFloat(a.total_days || 0), 0);
      }

      let punchDays = 0;
      if (hr_attendance_punches) {
        const punches = await hr_attendance_punches.findAll({
          where: {
            employee_id: employeeId,
            status: 'Leave',
            leave_type_id: lt.id,
            outlet_id: outletId
          }
        });
        punches.forEach(p => {
          if (p.hours_worked > 0 && p.hours_worked <= 4) {
            punchDays += 0.5;
          } else {
            punchDays += 1.0;
          }
        });
      }

      bal.used_quota = appDays + punchDays;
      await bal.save();
    }
  } catch (err) {
    console.error('Error recalculating leave balances:', err.message);
  }
}

exports.getAttendance = async (req, res) => {
  try {
    const { hr_attendance_punches } = req.propertyDb.models;
    const { employee_id, month } = req.query; // month format YYYY-MM
    const where = { outlet_id: req.user.outlet_id };
    
    if (employee_id) where.employee_id = employee_id;
    if (month) {
      const startDate = moment(month, 'YYYY-MM').startOf('month').format('YYYY-MM-DD');
      const endDate = moment(month, 'YYYY-MM').endOf('month').format('YYYY-MM-DD');
      where.punch_date = { [Op.between]: [startDate, endDate] };
    }
    
    const data = await hr_attendance_punches.findAll({
      where,
      order: [['punch_date', 'ASC']]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.punchIn = async (req, res) => {
  try {
    const { hr_attendance_punches, hr_employees, hr_payroll_runs } = req.propertyDb.models;
    
    const monthStr = moment().format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && monthStr <= latestLockedRun.pay_period) {
      return res.status(400).json({ success: false, message: `Punch-in is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }

    let employee_id = req.body.employee_id;
    
    if (!employee_id) {
      const emp = await hr_employees.findOne({
        where: { user_id: req.user.id, outlet_id: req.user.outlet_id }
      });
      if (!emp) {
        return res.status(400).json({ success: false, message: 'No employee record linked to your user account.' });
      }
      employee_id = emp.id;
    }

    const today = moment().format('YYYY-MM-DD');
    const now = moment().toDate();
    
    const [punch, created] = await hr_attendance_punches.findOrCreate({
      where: { employee_id, punch_date: today, outlet_id: req.user.outlet_id },
      defaults: {
        punch_in: now,
        punch_source: 'System',
        status: 'Present',
        outlet_id: req.user.outlet_id,
        created_by: req.user.id
      }
    });

    if (!created) {
      if (!punch.punch_in) {
        punch.punch_in = now;
        await punch.save();
      } else {
        return res.status(400).json({ success: false, message: 'Already punched in today' });
      }
    }
    
    return res.json({ success: true, data: punch });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.punchOut = async (req, res) => {
  try {
    const { hr_attendance_punches, hr_employees, hr_shifts, hr_payroll_runs } = req.propertyDb.models;
    
    const monthStr = moment().format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && monthStr <= latestLockedRun.pay_period) {
      return res.status(400).json({ success: false, message: `Punch-out is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }

    let employee_id = req.body.employee_id;
    
    if (!employee_id) {
      const emp = await hr_employees.findOne({
        where: { user_id: req.user.id, outlet_id: req.user.outlet_id }
      });
      if (!emp) {
        return res.status(400).json({ success: false, message: 'No employee record linked to your user account.' });
      }
      employee_id = emp.id;
    }

    const today = moment().format('YYYY-MM-DD');
    const now = moment().toDate();
    
    const punch = await hr_attendance_punches.findOne({
      where: { employee_id, punch_date: today, outlet_id: req.user.outlet_id }
    });
    
    if (!punch || !punch.punch_in) {
      return res.status(400).json({ success: false, message: 'Must punch in first' });
    }
    if (punch.punch_out) {
      return res.status(400).json({ success: false, message: 'Already punched out today' });
    }

    const employee = await hr_employees.findByPk(employee_id, {
      include: [{ model: hr_shifts, as: 'shift' }]
    });

    punch.punch_out = now;
    
    const start = moment(punch.punch_in);
    const end = moment(now);
    const workedMinutes = end.diff(start, 'minutes');
    punch.hours_worked = parseFloat((workedMinutes / 60).toFixed(2));
    
    if (employee && employee.shift) {
      const shift = employee.shift;
      
      const shiftStartStr = `${today} ${shift.start_time}`;
      const shiftStart = moment(shiftStartStr, 'YYYY-MM-DD HH:mm:ss');
      const shiftEndStr = `${today} ${shift.end_time}`;
      const shiftEnd = moment(shiftEndStr, 'YYYY-MM-DD HH:mm:ss');
      
      let shiftDurationMins = shiftEnd.diff(shiftStart, 'minutes');
      if (shiftDurationMins < 0) shiftDurationMins += 24 * 60; 
      
      const shiftDurationHours = shiftDurationMins / 60;

      const graceLimit = shiftStart.clone().add(shift.grace_period_mins || 0, 'minutes');
      if (start.isAfter(graceLimit)) {
        punch.lateness_mins = start.diff(shiftStart, 'minutes');
      } else {
        punch.lateness_mins = 0;
      }
      
      if (punch.hours_worked > shiftDurationHours) {
        punch.overtime_hours = parseFloat((punch.hours_worked - shiftDurationHours).toFixed(2));
      } else {
        punch.overtime_hours = 0;
      }
      
      if (punch.hours_worked < shiftDurationHours / 2) {
        punch.status = 'Absent';
      } else if (punch.hours_worked < shiftDurationHours) {
        punch.status = 'Half-Day';
      } else {
        punch.status = 'Present';
      }
    } else {
      punch.status = 'Present';
      punch.lateness_mins = 0;
      punch.overtime_hours = 0;
    }
    
    await punch.save();
    return res.json({ success: true, data: punch });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.manualAttendance = async (req, res) => {
  try {
    const { hr_attendance_punches, hr_payroll_runs } = req.propertyDb.models;
    const { employee_id, punch_date, punch_in, punch_out, status, hours_worked, overtime_hours, lateness_mins, punch_source, leave_type_id } = req.body;

    const monthStr = moment(punch_date).format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && monthStr <= latestLockedRun.pay_period) {
      return res.status(400).json({ success: false, message: `Attendance editing is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }
    
    let computedHours = 0;
    if (hours_worked !== undefined && hours_worked !== null) {
      computedHours = parseFloat(hours_worked);
    } else if (punch_in && punch_out) {
      computedHours = parseFloat((moment(punch_out).diff(moment(punch_in), 'minutes') / 60).toFixed(2));
    }
    
    let punch = await hr_attendance_punches.findOne({
      where: {
        employee_id,
        punch_date,
        outlet_id: req.user.outlet_id
      }
    });

    if (punch) {
      punch.punch_in = punch_in || null;
      punch.punch_out = punch_out || null;
      punch.status = status || 'Present';
      punch.hours_worked = computedHours;
      punch.overtime_hours = parseFloat(overtime_hours || 0.0);
      punch.lateness_mins = parseInt(lateness_mins || 0);
      punch.punch_source = punch_source || 'Manual';
      punch.updated_by = req.user.id;
      punch.leave_type_id = leave_type_id || null;
      await punch.save();
    } else {
      punch = await hr_attendance_punches.create({
        outlet_id: req.user.outlet_id,
        employee_id,
        punch_date,
        punch_in: punch_in || null,
        punch_out: punch_out || null,
        status: status || 'Present',
        hours_worked: computedHours,
        overtime_hours: parseFloat(overtime_hours || 0.0),
        lateness_mins: parseInt(lateness_mins || 0),
        punch_source: punch_source || 'Manual',
        updated_by: req.user.id,
        leave_type_id: leave_type_id || null
      });
    }

    // Trigger leave balance recalculation
    await recalculateLeaveBalances(employee_id, req.user.outlet_id, req.propertyDb);
    
    return res.json({ success: true, data: punch });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== LEAVES ====================

exports.getLeaves = async (req, res) => {
  try {
    const { hr_leave_applications, hr_employees, hr_leave_types } = req.propertyDb.models;
    const { employee_id, status } = req.query;
    
    const where = { outlet_id: req.user.outlet_id };
    if (employee_id) where.employee_id = employee_id;
    if (status) where.status = status;
    
    const data = await hr_leave_applications.findAll({
      where,
      include: [
        { model: hr_employees, as: 'employee' },
        { model: hr_leave_types, as: 'leaveType' }
      ]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.applyLeave = async (req, res) => {
  try {
    const { hr_leave_applications, hr_leave_balances, hr_payroll_runs } = req.propertyDb.models;
    const { employee_id, leave_type_id, start_date, end_date, reason } = req.body;
    
    const startMonth = moment(start_date).format('YYYY-MM');
    const endMonth = moment(end_date).format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && (startMonth <= latestLockedRun.pay_period || endMonth <= latestLockedRun.pay_period)) {
      return res.status(400).json({ success: false, message: `Leave application is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }
    
    const start = moment(start_date);
    const end = moment(end_date);
    let total_days = 0;
    
    for (let m = start.clone(); m.isSameOrBefore(end); m.add(1, 'days')) {
      if (m.isoWeekday() !== 6 && m.isoWeekday() !== 7) { 
        total_days++;
      }
    }
    
    if (total_days === 0) total_days = 1;
    
    const currentYear = start.year();
    const balance = await hr_leave_balances.findOne({
      where: { employee_id, leave_type_id, year: currentYear, outlet_id: req.user.outlet_id }
    });
    
    if (!balance || (balance.total_quota - balance.used_quota) < total_days) {
      return res.status(400).json({ success: false, message: 'Insufficient leave balance' });
    }
    
    const application = await hr_leave_applications.create({
      employee_id, leave_type_id, start_date, end_date, total_days, reason,
      status: 'Pending',
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });
    
    return res.json({ success: true, data: application });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.approveLeave = async (req, res) => {
  try {
    const { hr_leave_applications, hr_leave_balances, hr_attendance_punches, hr_leave_types, hr_payroll_runs } = req.propertyDb.models;
    const app = await hr_leave_applications.findOne({
      where: { id: req.params.id, outlet_id: req.user.outlet_id },
      include: [{ model: hr_leave_types, as: 'leaveType' }]
    });
    if (!app) return res.status(404).json({ success: false, message: 'Leave not found' });

    const startMonth = moment(app.start_date).format('YYYY-MM');
    const endMonth = moment(app.end_date).format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && (startMonth <= latestLockedRun.pay_period || endMonth <= latestLockedRun.pay_period)) {
      return res.status(400).json({ success: false, message: `Leave approval is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }
    
    app.status = 'Approved';
    app.approved_by = req.user.id;
    await app.save();
    
    const start = moment(app.start_date);
    const currentYear = start.year();
    const balance = await hr_leave_balances.findOne({
      where: { employee_id: app.employee_id, leave_type_id: app.leave_type_id, year: currentYear }
    });
    
    if (balance) {
      balance.used_quota = (parseFloat(balance.used_quota) || 0) + app.total_days;
      await balance.save();
    }
    
    const isPaid = app.leaveType ? app.leaveType.is_paid : true;
    const leaveStatus = isPaid ? 'Leave' : 'Unpaid Leave';
    
    const end = moment(app.end_date);
    for (let m = start.clone(); m.isSameOrBefore(end); m.add(1, 'days')) {
      const dateStr = m.format('YYYY-MM-DD');
      let punch = await hr_attendance_punches.findOne({
        where: {
          employee_id: app.employee_id,
          punch_date: dateStr,
          outlet_id: req.user.outlet_id
        }
      });
      if (punch) {
        punch.status = leaveStatus;
        punch.punch_source = 'System';
        punch.updated_by = req.user.id;
        punch.leave_type_id = app.leave_type_id;
        await punch.save();
      } else {
        await hr_attendance_punches.create({
          outlet_id: req.user.outlet_id,
          employee_id: app.employee_id,
          punch_date: dateStr,
          status: leaveStatus,
          punch_source: 'System',
          updated_by: req.user.id,
          leave_type_id: app.leave_type_id
        });
      }
    }

    // Recalculate leave balances for consistency
    await recalculateLeaveBalances(app.employee_id, req.user.outlet_id, req.propertyDb);
    
    return res.json({ success: true, message: 'Leave approved' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.rejectLeave = async (req, res) => {
  try {
    const { hr_leave_applications } = req.propertyDb.models;
    const [updated] = await hr_leave_applications.update({ status: 'Rejected' }, {
      where: { id: req.params.id, outlet_id: req.user.outlet_id }
    });
    if (!updated) return res.status(404).json({ success: false, message: 'Not found' });
    return res.json({ success: true, message: 'Leave rejected' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== LOANS ====================

exports.getLoans = async (req, res) => {
  try {
    const { hr_loans, hr_loan_transactions } = req.propertyDb.models;
    const { employee_id } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    if (employee_id) where.employee_id = employee_id;
    
    const data = await hr_loans.findAll({
      where,
      include: [{ model: hr_loan_transactions, as: 'transactions' }]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createLoan = async (req, res) => {
  const transaction = await req.propertyDb.transaction();
  try {
    const { hr_loans, hr_employees, expenses, expense_categories, cash_ledger } = req.propertyDb.models;
    const { loan_amount, employee_id, payment_method } = req.body;
    
    const data = await hr_loans.create({
      ...req.body,
      remaining_balance: loan_amount,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    }, { transaction });

    const emp = await hr_employees.findByPk(employee_id, { transaction });
    const empName = emp ? emp.full_name : 'Employee';
    const empCode = emp ? emp.employee_code : '';
    const method = payment_method || 'Cash';

    // Log Expense
    let categoryId = null;
    if (expenses && expense_categories) {
      const [category] = await expense_categories.findOrCreate({
        where: { category_name: 'Loans & Advances', outlet_id: req.user.outlet_id },
        defaults: { category_name: 'Loans & Advances', user_id: req.user.id },
        transaction
      });
      categoryId = category.id;
      
      await expenses.create({
        category_id: categoryId,
        base_amount: parseFloat(loan_amount),
        net_payable_amount: parseFloat(loan_amount),
        payment_date: new Date(),
        expense_note: `Loan Reference #${data.id} issued to ${empName} (${empCode})`,
        payment_method: method,
        status: 'Paid',
        outlet_id: req.user.outlet_id,
        created_by: req.user.id
      }, { transaction });
    }

    // Log Cash Ledger
    if (cash_ledger) {
      await cash_ledger.create({
        outlet_id: req.user.outlet_id,
        txn_date: moment().format('YYYY-MM-DD'),
        transaction_type: 'EXPENSE',
        reference_type: 'LOAN',
        reference_id: data.id.toString(),
        reference_no: `LOAN-ISSUED-${data.id}`,
        party_name: empName,
        payment_method: method,
        notes: `Loan Reference #${data.id} issued to ${empName} (${empCode})`,
        amount_out: parseFloat(loan_amount),
        amount_in: 0,
        created_by: req.user.id
      }, { transaction });
    }

    await transaction.commit();
    return res.json({ success: true, data });
  } catch (err) {
    await transaction.rollback();
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateLoanStatus = async (req, res) => {
  try {
    const { hr_loans } = req.propertyDb.models;
    const { status } = req.body;
    const [updated] = await hr_loans.update({ status }, {
      where: { id: req.params.id, outlet_id: req.user.outlet_id }
    });
    if (!updated) return res.status(404).json({ success: false, message: 'Not found' });
    return res.json({ success: true, message: 'Status updated' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== PAYROLL ====================

exports.previewPayroll = async (req, res) => {
  try {
    const {
      hr_employees,
      hr_shifts,
      hr_attendance_punches,
      hr_sales_commissions,
      hr_loans,
      hr_cashier_handovers,
      outlet_settings,
      hr_holidays,
      hr_arrears
    } = req.propertyDb.models;
    const { pay_period } = req.body;
    
    const start = moment(pay_period, 'YYYY-MM').startOf('month');
    const end = moment(pay_period, 'YYYY-MM').endOf('month');
    const total_days = end.date();
    
    const settingsRecord = await outlet_settings.findOne({ where: { outlet_id: req.user.outlet_id } });
    const paySchedule = (settingsRecord && settingsRecord.settings && settingsRecord.settings.pay_schedule) || {
      calculation_method: 'Actual Days',
      fixed_working_days: 26,
      working_hours_per_day: 8.0,
      holiday_work_policy: 'Normal Pay',
      holiday_overtime_multiplier: 1.5
    };
    
    const calculationMethod = paySchedule.calculation_method || 'Actual Days';
    const fixedWorkingDays = parseInt(paySchedule.fixed_working_days) || 26;
    const workingHoursPerDay = parseFloat(paySchedule.working_hours_per_day) || 8.0;
    const holidayWorkPolicy = paySchedule.holiday_work_policy || 'Normal Pay';
    const holidayOvertimeMultiplier = parseFloat(paySchedule.holiday_overtime_multiplier) || 1.5;

    const holidays = await hr_holidays.findAll({
      where: {
        outlet_id: req.user.outlet_id,
        holiday_date: { [Op.between]: [start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD')] }
      }
    });
    const holidayDates = holidays.map(h => h.holiday_date);
    
    const { hr_pay_structures, hr_salary_components } = req.propertyDb.models;
    const employees = await hr_employees.findAll({
      where: { status: 'Active', outlet_id: req.user.outlet_id },
      include: [
        { model: hr_shifts, as: 'shift' },
        {
          model: hr_pay_structures,
          as: 'payStructure',
          include: [
            { model: hr_salary_components, as: 'components' }
          ]
        }
      ]
    });
    
    const results = [];
    
    for (const emp of employees) {
      // Calculate active dates in the month based on hire date and termination date
      const monthStart = moment(start);
      const monthEnd = moment(end);
      
      // 1. Fetch punches for the entire month first
      const punches = await hr_attendance_punches.findAll({
        where: {
          employee_id: emp.id,
          punch_date: { [Op.between]: [monthStart.format('YYYY-MM-DD'), monthEnd.format('YYYY-MM-DD')] },
          outlet_id: req.user.outlet_id
        }
      });

      const empHireDate = moment(emp.hire_date);
      let calcStart = monthStart;
      if (empHireDate.isAfter(monthStart)) {
        // If there are punches in this month before the hire date, override and start from monthStart!
        const hasPunchesBeforeHire = punches.some(p => moment(p.punch_date).isBefore(empHireDate));
        if (!hasPunchesBeforeHire) {
          calcStart = empHireDate;
        }
      }
      
      let calcEnd = monthEnd;
      if (emp.terminated_date) {
        const empTermDate = moment(emp.terminated_date);
        if (empTermDate.isBefore(monthEnd)) {
          calcEnd = empTermDate;
        }
      }
      
      if (calcStart.isAfter(monthEnd) || calcEnd.isBefore(monthStart)) {
        continue; 
      }

const activeDaysInPeriod = calcEnd.diff(calcStart, 'days') + 1;
      
      let present = 0, half_day = 0, absent = 0, on_leave = 0, unpaid_leave = 0;
      let weekly_offs_count = 0, holidays_count = 0;
      let total_working_hours = 0, total_overtime_hours = 0, total_late_mins = 0;
      let total_less_hours = 0;

      for (let d = moment(calcStart); d.isSameOrBefore(calcEnd); d.add(1, 'days')) {
        const dateStr = d.format('YYYY-MM-DD');
        const punch = punches.find(p => p.punch_date === dateStr);
        const isHoliday = holidayDates.includes(dateStr);
        
        let isWeeklyOff = false;
        const shift = emp.shift || {};
        const weeklyOffs = shift.weekly_offs || ['Sunday'];
        const dayName = d.format('dddd');
        if (weeklyOffs.includes(dayName)) {
          isWeeklyOff = true;
        } else if (dayName === 'Saturday') {
          let satCount = 0;
          for (let w = 1; w <= d.date(); w++) {
            if (moment(d).date(w).day() === 6) satCount++;
          }
          const checkStr = `${satCount}${satCount === 1 ? 'st' : satCount === 2 ? 'nd' : satCount === 3 ? 'rd' : 'th'} Saturday`;
          if (weeklyOffs.includes(checkStr)) {
            isWeeklyOff = true;
          }
        }

        if (isHoliday) {
          holidays_count++;
          if (punch) {
            const hw = parseFloat(punch.hours_worked) || 0.0;
            total_overtime_hours += hw;
          }
        } else if (isWeeklyOff) {
          weekly_offs_count++;
          if (punch) {
            const hw = parseFloat(punch.hours_worked) || 0.0;
            total_overtime_hours += hw;
          }
        } else {
          // Normal working day
          if (punch) {
            total_working_hours += parseFloat(punch.hours_worked) || 0;
            total_late_mins += parseInt(punch.lateness_mins) || 0;

            if (punch.status === 'Present') present++;
            else if (punch.status === 'Half-Day' || punch.status === 'Half Day') half_day++;
            else if (punch.status === 'Absent') absent++;
            else if (punch.status === 'Leave' || punch.status === 'On-Leave') on_leave++;
            else if (punch.status === 'Unpaid Leave') unpaid_leave++;

            const hw = parseFloat(punch.hours_worked) || 0.0;
            if (hw > workingHoursPerDay) {
              total_overtime_hours += (hw - workingHoursPerDay);
            } else if (hw < workingHoursPerDay && (punch.status === 'Present' || punch.status === 'Half-Day' || punch.status === 'Half Day')) {
              total_less_hours += (workingHoursPerDay - hw);
            }
          } else {
            // No punch record for this working day
            if (emp.pay_if_unmarked) {
              // Special policy: employee receives pay even without daily attendance records
              // (e.g. management, off-site, or contractual staff)
              present++;
            } else {
              // Default enterprise policy: no punch = absent = no pay for that day
              // This applies to both past AND future unpunched days.
              // Running payroll mid-month or in advance pays only for verified attendance.
              absent++;
            }
          }
        }
      }
      
      // ── Payroll Calculation ─────────────────────────────────────────────────────
      // Enterprise standard: Full monthly salary minus deductions for absent days.
      // Divisor = total working days in active period (excludes weekly offs & holidays).
      // Per-day rate = base_salary / divisor.
      // Paid days = present + (0.5 × half_day) + on_leave (approved paid leave).
      // Absent deduction = absent_days × per_day_rate (no pay for missed working days).
      
      const absentDays = absent + (0.5 * half_day);
      const divisor = (calculationMethod === 'Fixed Days') 
        ? fixedWorkingDays 
        : Math.max(1, activeDaysInPeriod - weekly_offs_count - holidays_count);
      
      const salary_days = present + (0.5 * half_day) + on_leave;
      const prorated_salary_days = Math.min(divisor, salary_days);

      const base = parseFloat(emp.base_salary) || 0;
      // Per-day salary rate
      const perDayRate = base / divisor;
      // Salary = (paid_days / divisor) × monthly_base
      let prorated_salary = parseFloat((perDayRate * prorated_salary_days).toFixed(2));

      // If employee has zero verified attendance and no approved leaves → zero salary
      // Used as a flag to skip commissions/bonuses for completely absent employees
      const salaryOverrideZero = prorated_salary_days === 0;
      if (salaryOverrideZero) {
        absent = divisor; // all working days marked absent for display
        prorated_salary = 0;
      }
      
      let commissions = 0;
      if (hr_sales_commissions && !salaryOverrideZero) {
        const comms = await hr_sales_commissions.findAll({
          where: {
            employee_id: emp.id,
            status: { [Op.in]: ['Queued', 'Pending'] },
            outlet_id: req.user.outlet_id
          }
        });
        commissions = comms.reduce((sum, c) => sum + parseFloat(c.commission_amount || 0), 0);
      }
      
      let loan_deduction = 0;
      if (!salaryOverrideZero) {
        const loans = await hr_loans.findAll({
          where: { employee_id: emp.id, status: 'Active', remaining_balance: { [Op.gt]: 0 }, outlet_id: req.user.outlet_id }
        });
        loans.forEach(loan => {
          loan_deduction += Math.min(parseFloat(loan.monthly_emi), parseFloat(loan.remaining_balance));
        });
      }
      
      let penalties = 0;
      if (hr_cashier_handovers && !salaryOverrideZero) {
        const hnds = await hr_cashier_handovers.findAll({
          where: { cashier_id: emp.id, shortage_status: 'Pending', variance: { [Op.lt]: 0 }, outlet_id: req.user.outlet_id }
        });
        penalties = hnds.reduce((sum, h) => sum + Math.abs(parseFloat(h.variance)), 0);
      }

      let empBonuses = 0;
      if (hr_arrears && !salaryOverrideZero) {
        const arrs = await hr_arrears.findAll({
          where: {
            employee_id: emp.id,
            payment_month: pay_period,
            status: 'Pending',
            outlet_id: req.user.outlet_id
          }
        });
        empBonuses = arrs.reduce((sum, a) => sum + parseFloat(a.amount || 0), 0);
      }

      const hourlyRate = base / divisor / workingHoursPerDay;
      const overtimePay = salaryOverrideZero ? 0 : parseFloat((total_overtime_hours * hourlyRate * (holidayOvertimeMultiplier || 1.5)).toFixed(2));
      const less_hours_debit = salaryOverrideZero ? 0 : parseFloat((total_less_hours * hourlyRate).toFixed(2));
      
      const payStructure = emp.payStructure || {};
      const components = payStructure.components || [];

      let basic = prorated_salary; 
      const basicComp = components.find(c => c.name.toLowerCase().includes('basic'));
      if (basicComp) {
        const type = basicComp.type;
        const formula = basicComp.formula || '';
        if (type === 'Percentage') {
          const pct = parseFloat(formula.replace(/%/g, '').trim()) || 50.0;
          basic = prorated_salary * (pct / 100.0);
        } else if (type === 'Formula') {
          basic = evalFormula(formula, prorated_salary, prorated_salary);
        } else if (type === 'Fixed') {
          const fixedAmt = parseFloat(formula) || 0.0;
          basic = salaryOverrideZero ? 0 : parseFloat(((fixedAmt / divisor) * prorated_salary_days).toFixed(2));
        }
      }

      let extraEarnings = 0;
      let extraDeductions = 0;
      const breakdown = { payment_status: 'Unpaid', payment_method: 'Cash' };

      for (const comp of components) {
        if (basicComp && comp.id === basicComp.id) {
          breakdown[comp.name] = basic;
          continue;
        }

        let val = 0;
        if (!salaryOverrideZero) {
          if (comp.type === 'Fixed') {
            const fixedAmt = parseFloat(comp.formula) || 0.0;
            val = parseFloat(((fixedAmt / divisor) * prorated_salary_days).toFixed(2));
          } else if (comp.type === 'Percentage') {
            const pct = parseFloat(comp.formula.replace(/%/g, '').trim()) || 0.0;
            val = basic * (pct / 100.0);
          } else if (comp.type === 'Formula') {
            val = evalFormula(comp.formula, prorated_salary, basic);
          }
        }

        breakdown[comp.name] = val;

        if (comp.nature === 'Earning') {
          extraEarnings += val;
        } else if (comp.nature === 'Deduction') {
          extraDeductions += val;
        }
      }

      const absent_deduction_amount = salaryOverrideZero ? 0 : ((base / divisor) * absentDays);

      breakdown.attendance_analytics = {
        total_working_hours,
        total_overtime_hours,
        total_late_mins,
        total_less_hours,
        weekdays_count: weekly_offs_count,
        holidays_count,
        required_hours: Math.round((activeDaysInPeriod - weekly_offs_count - holidays_count) * workingHoursPerDay),
        completed_hours: parseFloat(total_working_hours.toFixed(2)),
        overtime_addition_amount: overtimePay,
        late_deduction_amount: 0.00,
        absent_deduction_amount: parseFloat(absent_deduction_amount.toFixed(2)),
        less_hours_debit_amount: less_hours_debit,
        unpaid_leave_count: unpaid_leave,
        unpaid_leave_deduction_amount: parseFloat(((base / divisor) * unpaid_leave).toFixed(2))
      };

      const unpaid_leave_deduction_amount = parseFloat(((base / divisor) * unpaid_leave).toFixed(2));

      let gross_earnings = 0;
      if (components.length > 0) {
        gross_earnings = basic + extraEarnings;
      } else {
        gross_earnings = prorated_salary;
      }

      const gross = gross_earnings + commissions + overtimePay + empBonuses;
      const total_deductions = loan_deduction + penalties + extraDeductions + less_hours_debit;
      const net = gross - total_deductions;

      results.push({
        employee_id: emp.id,
        employee_name: emp.full_name,
        employee_code: emp.employee_code,
        base_salary: base,
        total_days, present, half_day, absent, on_leave,
        unpaid_leave,
        unpaid_leave_deduction_amount,
        salary_days: prorated_salary_days, 
        prorated_salary,
        commissions, bonuses: empBonuses, arrears: 0,
        overtime_pay: overtimePay,
        earned_comp_offs: 0,
        gross_pay: gross,
        loan_deduction,
        penalty_deduction: penalties,
        statutory_deductions: extraDeductions,
        total_deductions: total_deductions,
        net_pay: net,
        components_breakdown: breakdown,
        
        total_working_hours,
        total_overtime_hours,
        total_late_mins,
        total_less_hours,
        weekdays_count: weekly_offs_count,
        holidays_count,
        required_hours: Math.round((activeDaysInPeriod - weekly_offs_count - holidays_count) * workingHoursPerDay),
        completed_hours: parseFloat(total_working_hours.toFixed(2)),
        overtime_addition_amount: overtimePay,
        late_deduction_amount: 0.00,
        absent_deduction_amount: parseFloat(absent_deduction_amount.toFixed(2)),
        less_hours_debit_amount: less_hours_debit,
        unpaid_leave_count: unpaid_leave,
        unpaid_leave_deduction_amount
      });
    }
    
    return res.json({ success: true, data: results });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.runPayroll = async (req, res) => {
  try {
    const { pay_period } = req.body;
    const { hr_payroll_runs, hr_payroll_details, hr_sales_commissions, hr_loans, hr_loan_transactions, hr_cashier_handovers, hr_arrears, hr_employees, cash_ledger } = req.propertyDb.models;
    
    // Check if there is already an Approved run for this month
    const existingApproved = await hr_payroll_runs.findOne({
      where: { pay_period, status: 'Approved', outlet_id: req.user.outlet_id }
    });
    if (existingApproved) {
      return res.status(400).json({ success: false, message: 'Payroll for this month is already approved and locked!' });
    }

    // Delete existing Draft runs for this month to prevent duplicates
    await hr_payroll_runs.destroy({
      where: { pay_period, status: 'Draft', outlet_id: req.user.outlet_id }
    });

    // Quick trick: call preview logic directly using a mock res object
    let previewData = null;
    const mockRes = {
      json: (data) => { previewData = data; },
      status: (code) => ({ json: (data) => { throw new Error(data.message); } })
    };
    await exports.previewPayroll(req, mockRes);
    
    if (!previewData || !previewData.success) throw new Error('Preview failed');
    const details = previewData.data;
    
    const totalGross = details.reduce((sum, d) => sum + d.gross_pay, 0);
    const totalDeductions = details.reduce((sum, d) => sum + d.total_deductions, 0);
    const totalNet = details.reduce((sum, d) => sum + d.net_pay, 0);
    
    const run = await hr_payroll_runs.create({
      pay_period,
      run_date: moment().format('YYYY-MM-DD'),
      status: 'Draft',
      total_gross: totalGross,
      total_deductions: totalDeductions,
      total_net: totalNet,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });
    
    const detailRows = details.map(d => ({
      payroll_run_id: run.id,
      employee_id: d.employee_id,
      base_salary: d.base_salary,
      prorated_salary: d.prorated_salary,
      overtime_pay: d.overtime_pay || 0.0,
      sales_commission: d.commissions || 0.0,
      bonuses: d.bonuses || 0.0,
      arrears: d.arrears || 0.0,
      shortage_penalties: d.penalty_deduction || 0.0,
      loan_emi: d.loan_deduction || 0.0,
      statutory_deductions: d.statutory_deductions || 0.0,
      total_deductions: d.total_deductions,
      gross_pay: d.gross_pay,
      net_pay: d.net_pay,
      days_present: d.present || 0.0,
      days_absent: d.absent || 0.0,
      days_on_leave: d.on_leave || 0.0,
      components_breakdown: d.components_breakdown || {},
      outlet_id: req.user.outlet_id
    }));
    
    await hr_payroll_details.bulkCreate(detailRows);
    
    for (const d of details) {
      if (d.commissions > 0 && hr_sales_commissions) {
        await hr_sales_commissions.update(
          { status: 'Paid', payroll_run_id: run.id },
          {
            where: {
              employee_id: d.employee_id,
              status: { [Op.in]: ['Queued', 'Pending'] },
              outlet_id: req.user.outlet_id
            }
          }
        );
      }
      
      if (d.loan_deduction > 0) {
        const loans = await hr_loans.findAll({
          where: { employee_id: d.employee_id, status: 'Active', remaining_balance: { [Op.gt]: 0 }, outlet_id: req.user.outlet_id }
        });
        for (const loan of loans) {
          const deduction = Math.min(parseFloat(loan.monthly_emi), parseFloat(loan.remaining_balance));
          if (deduction > 0) {
            const tx = await hr_loan_transactions.create({
              loan_id: loan.id, transaction_date: new Date(),
              transaction_type: 'Repayment', amount: deduction, notes: 'Payroll deduction ' + pay_period,
              outlet_id: req.user.outlet_id, created_by: req.user.id
            });

            const emp = await hr_employees.findByPk(d.employee_id);
            const empName = emp ? emp.full_name : 'Employee';
            const empCode = emp ? emp.employee_code : '';

            if (cash_ledger) {
              await cash_ledger.create({
                outlet_id: req.user.outlet_id,
                txn_date: moment().format('YYYY-MM-DD'),
                transaction_type: 'INCOME',
                reference_type: 'LOAN_REPAYMENT',
                reference_id: tx.id.toString(),
                reference_no: `LOAN-REPAY-${tx.id}`,
                party_name: empName,
                payment_method: 'Cash',
                notes: `Loan installment repayment by ${empName} (${empCode}) via Payroll deduction ${pay_period} (Loan #${loan.id})`,
                amount_in: deduction,
                amount_out: 0,
                created_by: req.user.id
              });
            }

            loan.remaining_balance = parseFloat(loan.remaining_balance) - deduction;
            if (loan.remaining_balance <= 0) loan.status = 'Closed';
            await loan.save();
          }
        }
      }
      
      if (d.penalty_deduction > 0 && hr_cashier_handovers) {
        await hr_cashier_handovers.update(
          { shortage_status: 'PenaltyDeduction' },
          { where: { cashier_id: d.employee_id, shortage_status: 'Pending', variance: { [Op.lt]: 0 }, outlet_id: req.user.outlet_id } }
        );
      }

      // Credit Earned Comp-Offs to employee leave balance
      if (d.earned_comp_offs > 0) {
        const { hr_leave_types, hr_leave_balances } = req.propertyDb.models;
        let leaveType = await hr_leave_types.findOne({
          where: { name: 'Comp Off', outlet_id: req.user.outlet_id }
        });
        if (!leaveType) {
          leaveType = await hr_leave_types.create({
            name: 'Comp Off',
            is_paid: true,
            annual_quota: 0,
            is_active: true,
            outlet_id: req.user.outlet_id
          });
        }
        
        const currentYear = moment().year();
        let balance = await hr_leave_balances.findOne({
          where: { employee_id: d.employee_id, leave_type_id: leaveType.id, year: currentYear }
        });
        if (!balance) {
          await hr_leave_balances.create({
            employee_id: d.employee_id,
            leave_type_id: leaveType.id,
            year: currentYear,
            allocated_quota: d.earned_comp_offs,
            used_quota: 0.0,
            outlet_id: req.user.outlet_id
          });
        } else {
          balance.allocated_quota = (parseFloat(balance.allocated_quota) || 0.0) + d.earned_comp_offs;
          await balance.save();
        }
      }

      if (d.bonuses > 0 && hr_arrears) {
        await hr_arrears.update(
          { status: 'Paid' },
          { where: { employee_id: d.employee_id, payment_month: pay_period, status: 'Pending', outlet_id: req.user.outlet_id } }
        );
      }
    }
    
    return res.json({ success: true, data: run });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.approvePayroll = async (req, res) => {
  try {
    const { hr_payroll_runs } = req.propertyDb.models;
    const run = await hr_payroll_runs.findOne({ where: { id: req.params.id, outlet_id: req.user.outlet_id } });
    if (!run) return res.status(404).json({ success: false, message: 'Not found' });
    
    run.status = 'Approved';
    run.approved_by = req.user.id;
    await run.save();
    
    return res.json({ success: true, message: 'Payroll approved' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getPayslip = async (req, res) => {
  try {
    const { hr_payroll_details, hr_employees, hr_payroll_runs, hr_designations, hr_pay_structures } = req.propertyDb.models;
    const { id, employeeId } = req.params;
    const detail = await hr_payroll_details.findOne({
      where: { payroll_run_id: id, employee_id: employeeId, outlet_id: req.user.outlet_id },
      include: [
        {
          model: hr_employees,
          as: 'employee',
          include: [
            { model: hr_designations, as: 'designation' },
            {
              model: hr_pay_structures,
              as: 'payStructure',
              include: [{
                model: req.propertyDb.models.hr_salary_components,
                as: 'components',
                through: { attributes: [] }
              }]
            }
          ]
        },
        { model: hr_payroll_runs, as: 'payrollRun' }
      ]
    });
    if (!detail) return res.status(404).json({ success: false, message: 'Not found' });
    return res.json({ success: true, data: detail });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getPayrollDashboardStats = async (req, res) => {
  try {
    const { hr_payroll_runs, hr_payroll_details } = req.propertyDb.models;
    
    const requestedPeriod = req.query.pay_period || null;
    
    let targetRun = null;
    if (requestedPeriod) {
      // Strict lookup: only show data that belongs to the requested period
      // Prefer Approved, then Draft — never fall back to a different month
      targetRun = await hr_payroll_runs.findOne({
        where: { outlet_id: req.user.outlet_id, pay_period: requestedPeriod, status: 'Approved' }
      });
      if (!targetRun) {
        targetRun = await hr_payroll_runs.findOne({
          where: { outlet_id: req.user.outlet_id, pay_period: requestedPeriod, status: 'Draft' },
          order: [['created_at', 'DESC']]
        });
      }
    } else {
      // No period specified — fall back to latest approved run for general dashboard view
      targetRun = await hr_payroll_runs.findOne({
        where: { outlet_id: req.user.outlet_id, status: 'Approved' },
        order: [['pay_period', 'DESC']]
      });
    }

    let kpis = {
      pay_period: requestedPeriod || 'None',
      has_data: false,  // Frontend checks this — if false, hide the analytics summary section
      total_leave_deduction: 0,
      total_absent_deduction: 0,
      total_late_deduction: 0,
      total_overtime_paid: 0,
      total_bonuses_paid: 0,
      total_deductions: 0,
      total_net_paid: 0,
      increment_from_prev_month: 0
    };

    if (targetRun) {
      kpis.has_data = true;
      kpis.pay_period = targetRun.pay_period;
      kpis.total_net_paid = parseFloat(targetRun.total_net) || 0;
      kpis.total_deductions = parseFloat(targetRun.total_deductions) || 0;

      const details = await hr_payroll_details.findAll({
        where: { payroll_run_id: targetRun.id }
      });

      for (const d of details) {
        kpis.total_overtime_paid += parseFloat(d.overtime_pay || 0);
        kpis.total_bonuses_paid += parseFloat(d.bonuses || 0);

        const breakdown = d.components_breakdown || {};
        const analytics = breakdown.attendance_analytics || {};
        kpis.total_leave_deduction += parseFloat(analytics.unpaid_leave_deduction_amount || 0);
        kpis.total_absent_deduction += parseFloat(analytics.absent_deduction_amount || 0);
        kpis.total_late_deduction += parseFloat(analytics.less_hours_debit_amount || 0);
      }

      // Format decimals
      kpis.total_leave_deduction = parseFloat(kpis.total_leave_deduction.toFixed(2));
      kpis.total_absent_deduction = parseFloat(kpis.total_absent_deduction.toFixed(2));
      kpis.total_late_deduction = parseFloat(kpis.total_late_deduction.toFixed(2));
      kpis.total_overtime_paid = parseFloat(kpis.total_overtime_paid.toFixed(2));
      kpis.total_bonuses_paid = parseFloat(kpis.total_bonuses_paid.toFixed(2));

      // Compare with same period last month (approved runs only for increment comparison)
      const momentPrev = moment(targetRun.pay_period, 'YYYY-MM').subtract(1, 'month').format('YYYY-MM');
      const prevRun = await hr_payroll_runs.findOne({
        where: { pay_period: momentPrev, status: 'Approved', outlet_id: req.user.outlet_id }
      });
      if (prevRun) {
        const extraPaid = (parseFloat(targetRun.total_net) || 0) - (parseFloat(prevRun.total_net) || 0);
        kpis.increment_from_prev_month = parseFloat(extraPaid.toFixed(2));
      }
    }

    // Chart data: always show last 6 approved runs for historical context
    const runs = await hr_payroll_runs.findAll({
      where: { outlet_id: req.user.outlet_id, status: 'Approved' },
      order: [['pay_period', 'DESC']],
      limit: 6
    });
    runs.sort((a, b) => a.pay_period.localeCompare(b.pay_period));
    
    return res.json({ 
      success: true, 
      kpis,
      data: runs 
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== CASHIER HANDOVER ====================

function extractCashFromSaleHeader(s) {
  const status = String(s.status || '').trim().toUpperCase();
  if (status === 'CANCELLED' || status === 'DRAFT') return 0;

  const paymentMode = String(s.payment_mode || '').trim().toUpperCase();
  const netAmount = parseFloat(s.net_amount || 0);
  const amountPaid = parseFloat(s.amount_paid || 0);
  const changeAmount = parseFloat(s.change_amount || 0);
  const paymentRef = String(s.payment_reference || '').trim();

  if (paymentRef.startsWith('POSPAY:')) {
    try {
      const parsed = JSON.parse(paymentRef.substring(7));
      if (Array.isArray(parsed) && parsed.length > 0) {
        let cashSum = 0;
        for (const line of parsed) {
          const method = String(line?.method || '').trim().toUpperCase();
          const amt = parseFloat(line?.amount || 0);
          if (method === 'CASH') {
            cashSum += amt;
          }
        }
        if (changeAmount > 0 && cashSum > 0) {
          cashSum = Math.max(0, cashSum - changeAmount);
        }
        return cashSum;
      }
    } catch (_) {}
  }

  if (paymentMode === 'CASH') {
    if (netAmount > 0) return netAmount;
    return Math.max(0, amountPaid - changeAmount);
  }

  return 0;
}

exports.createHandover = async (req, res) => {
  try {
    const { hr_cashier_handovers, sales_headers } = req.propertyDb.models;
    const { Op } = req.propertyDb.Sequelize;
    const { cashier_id, handover_date, physical_cash, denominations } = req.body;
    
    const targetCashierId = cashier_id ? parseInt(cashier_id, 10) : req.user.id;
    const dateStr = handover_date || new Date().toISOString().split('T')[0];
    const startDate = new Date(`${dateStr}T00:00:00.000Z`);
    const endDate = new Date(`${dateStr}T23:59:59.999Z`);

    let expected_cash = 0;
    if (sales_headers) {
      const sales = await sales_headers.findAll({
        where: { 
          created_by: targetCashierId, 
          sale_date: { [Op.gte]: startDate, [Op.lte]: endDate }, 
          outlet_id: req.user.outlet_id,
          status: { [Op.ne]: 'Cancelled' }
        }
      });

      expected_cash = sales.reduce((sum, s) => sum + extractCashFromSaleHeader(s), 0);
    }
    
    const physicalCashNum = parseFloat(physical_cash || 0);
    const variance = physicalCashNum - expected_cash;
    let shortage_status = 'Matched';
    if (variance < -0.01) shortage_status = 'Pending';
    else if (variance > 0.01) shortage_status = 'Surplus';
    
    const handover = await hr_cashier_handovers.create({
      cashier_id: targetCashierId,
      handover_date: dateStr,
      expected_cash,
      physical_cash: physicalCashNum,
      variance,
      denominations,
      shortage_status,
      outlet_id: req.user.outlet_id,
      created_by: req.user.id
    });
    
    return res.json({ success: true, data: handover });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getHandovers = async (req, res) => {
  try {
    const { hr_cashier_handovers, users } = req.propertyDb.models;
    const { Op } = req.propertyDb.Sequelize;
    const { cashier_id, from_date, to_date } = req.query;
    const where = { outlet_id: req.user.outlet_id };
    
    if (cashier_id) where.cashier_id = cashier_id;
    if (from_date && to_date) {
      where.handover_date = { [Op.between]: [from_date, to_date] };
    } else if (from_date) {
      where.handover_date = { [Op.gte]: from_date };
    } else if (to_date) {
      where.handover_date = { [Op.lte]: to_date };
    }
    
    const handovers = await hr_cashier_handovers.findAll({
      where,
      include: [
        { 
          model: users, 
          as: 'cashier', 
          attributes: ['id', 'username', 'full_name', 'contact_email'],
          required: false
        }
      ],
      order: [['handover_date', 'DESC'], ['created_at', 'DESC']]
    });

    // Summary calculations
    let totalExpectedCash = 0;
    let totalPhysicalCash = 0;
    let totalVariance = 0;
    let shortageCount = 0;
    let surplusCount = 0;
    let matchedCount = 0;

    const cashierSummaryMap = {};

    handovers.forEach(h => {
      const exp = parseFloat(h.expected_cash || 0);
      const phy = parseFloat(h.physical_cash || 0);
      const vrc = parseFloat(h.variance || 0);

      totalExpectedCash += exp;
      totalPhysicalCash += phy;
      totalVariance += vrc;

      if (vrc < 0) shortageCount++;
      else if (vrc > 0) surplusCount++;
      else matchedCount++;

      const cId = h.cashier_id || 0;
      const cName = h.cashier?.full_name || h.cashier?.username || `Cashier #${cId}`;

      if (!cashierSummaryMap[cId]) {
        cashierSummaryMap[cId] = {
          cashier_id: cId,
          cashier_name: cName,
          total_handovers: 0,
          total_expected: 0,
          total_physical: 0,
          total_variance: 0,
          shortage_count: 0,
        };
      }

      cashierSummaryMap[cId].total_handovers += 1;
      cashierSummaryMap[cId].total_expected += exp;
      cashierSummaryMap[cId].total_physical += phy;
      cashierSummaryMap[cId].total_variance += vrc;
      if (vrc < 0) cashierSummaryMap[cId].shortage_count += 1;
    });

    return res.json({ 
      success: true, 
      data: handovers,
      summary: {
        total_handovers: handovers.length,
        total_expected_cash: totalExpectedCash,
        total_physical_cash: totalPhysicalCash,
        total_variance: totalVariance,
        shortage_count: shortageCount,
        surplus_count: surplusCount,
        matched_count: matchedCount,
        cashier_breakdown: Object.values(cashierSummaryMap)
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== UPDATE & DELETE MASTERS ====================

// DESIGNATIONS
exports.updateDesignation = async (req, res) => {
  try {
    const { hr_designations } = req.propertyDb.models;
    const { id } = req.params;
    const { name, is_active } = req.body;
    const item = await hr_designations.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Designation not found' });
    await item.update({ name, is_active: is_active !== false });
    return res.json({ success: true, data: item });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteDesignation = async (req, res) => {
  try {
    const { hr_designations, hr_employees } = req.propertyDb.models;
    const { id } = req.params;
    
    // Check if assigned to any employees
    const count = await hr_employees.count({ where: { designation_id: id, outlet_id: req.user.outlet_id } });
    if (count > 0) {
      return res.status(400).json({ success: false, message: 'Cannot delete: Designation is assigned to one or more employees.' });
    }

    const item = await hr_designations.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Designation not found' });
    await item.destroy();
    return res.json({ success: true, message: 'Designation deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// SHIFTS
exports.updateShift = async (req, res) => {
  try {
    const { hr_shifts } = req.propertyDb.models;
    const { id } = req.params;
    const { name, start_time, end_time, grace_period_mins, weekly_offs, is_active } = req.body;
    const item = await hr_shifts.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Shift not found' });
    await item.update({ name, start_time, end_time, grace_period_mins, weekly_offs, is_active: is_active !== false });
    return res.json({ success: true, data: item });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteShift = async (req, res) => {
  try {
    const { hr_shifts, hr_employees } = req.propertyDb.models;
    const { id } = req.params;
    
    // Check if assigned to any employees
    const count = await hr_employees.count({ where: { shift_id: id, outlet_id: req.user.outlet_id } });
    if (count > 0) {
      return res.status(400).json({ success: false, message: 'Cannot delete: Shift is assigned to one or more employees.' });
    }

    const item = await hr_shifts.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Shift not found' });
    await item.destroy();
    return res.json({ success: true, message: 'Shift deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// LEAVE TYPES
exports.updateLeaveType = async (req, res) => {
  try {
    const { hr_leave_types } = req.propertyDb.models;
    const { id } = req.params;
    const { name, annual_quota, is_paid, is_active } = req.body;
    const item = await hr_leave_types.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Leave type not found' });
    await item.update({ name, annual_quota, is_paid, is_active: is_active !== false });
    return res.json({ success: true, data: item });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteLeaveType = async (req, res) => {
  try {
    const { hr_leave_types, hr_leave_balances, hr_leave_applications } = req.propertyDb.models;
    const { id } = req.params;
    
    // Check if referenced in applications or employee balances
    const balanceCount = await hr_leave_balances.count({ where: { leave_type_id: id, outlet_id: req.user.outlet_id } });
    const appCount = await hr_leave_applications.count({ where: { leave_type_id: id, outlet_id: req.user.outlet_id } });
    if (balanceCount > 0 || appCount > 0) {
      return res.status(400).json({ success: false, message: 'Cannot delete: Leave type is assigned to employee balances or applications.' });
    }

    const item = await hr_leave_types.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Leave type not found' });
    await item.destroy();
    return res.json({ success: true, message: 'Leave type deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// SALARY COMPONENTS
exports.deleteSalaryComponent = async (req, res) => {
  try {
    const { hr_salary_components, hr_pay_structure_components } = req.propertyDb.models;
    const { id } = req.params;
    
    // Check if referenced in pay structures
    const count = await hr_pay_structure_components.count({ where: { salary_component_id: id } });
    if (count > 0) {
      return res.status(400).json({ success: false, message: 'Cannot delete: Component is assigned to one or more Pay Structures.' });
    }

    const item = await hr_salary_components.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Component not found' });
    await item.destroy();
    return res.json({ success: true, message: 'Salary component deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// PAY STRUCTURES
exports.updatePayStructure = async (req, res) => {
  try {
    const { hr_pay_structures, hr_pay_structure_components } = req.propertyDb.models;
    const { id } = req.params;
    const { name, description, is_active, componentIds } = req.body;
    
    const item = await hr_pay_structures.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Pay structure not found' });
    
    await item.update({ name, description: description || null, is_active: is_active !== false });
    
    if (Array.isArray(componentIds)) {
      // Clear old components and bulk insert new ones
      await hr_pay_structure_components.destroy({ where: { pay_structure_id: id } });
      if (componentIds.length > 0) {
        const rows = componentIds.map(cid => ({ pay_structure_id: id, salary_component_id: cid }));
        await hr_pay_structure_components.bulkCreate(rows);
      }
    }
    
    return res.json({ success: true, data: item });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deletePayStructure = async (req, res) => {
  try {
    const { hr_pay_structures, hr_employees } = req.propertyDb.models;
    const { id } = req.params;
    
    // Check if assigned to any employees
    const count = await hr_employees.count({ where: { pay_structure_id: id, outlet_id: req.user.outlet_id } });
    if (count > 0) {
      return res.status(400).json({ success: false, message: 'Cannot delete: Pay structure is assigned to one or more employees.' });
    }

    const item = await hr_pay_structures.findOne({ where: { id, outlet_id: req.user.outlet_id } });
    if (!item) return res.status(404).json({ success: false, message: 'Pay structure not found' });
    await item.destroy();
    return res.json({ success: true, message: 'Pay structure deleted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getPayrollHistory = async (req, res) => {
  try {
    const { hr_payroll_details, hr_payroll_runs, hr_employees } = req.propertyDb.models;
    const { employee_id, payroll_run_id, pay_period } = req.query;
    
    const where = {};
    if (employee_id) where.employee_id = employee_id;
    if (payroll_run_id) where.payroll_run_id = payroll_run_id;
    
    const runWhere = { outlet_id: req.user.outlet_id };
    if (pay_period) runWhere.pay_period = pay_period;
    
    const data = await hr_payroll_details.findAll({
      where,
      include: [
        {
          model: hr_payroll_runs,
          as: 'payrollRun',
          where: runWhere
        },
        {
          model: hr_employees,
          as: 'employee',
          include: [
            { model: req.propertyDb.models.hr_designations, as: 'designation' },
            {
              model: req.propertyDb.models.hr_pay_structures,
              as: 'payStructure',
              include: [{
                model: req.propertyDb.models.hr_salary_components,
                as: 'components',
                through: { attributes: [] }
              }]
            }
          ]
        }
      ],
      order: [['id', 'DESC']]
    });
    
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getPayrollSettings = async (req, res) => {
  try {
    const { outlet_settings } = req.propertyDb.models;
    let record = await outlet_settings.findOne({ where: { outlet_id: req.user.outlet_id } });
    if (!record) {
      record = await outlet_settings.create({
        outlet_id: req.user.outlet_id,
        settings: {
          pay_schedule: {
            calculation_method: 'Actual Days',
            fixed_working_days: 26,
            working_hours_per_day: 8.0,
            pay_date_type: 'Last Day',
            pay_date_value: 1,
            first_month: '',
            first_date: null,
            holiday_work_policy: 'Normal Pay',
            holiday_overtime_multiplier: 1.5
          }
        }
      });
    }
    
    const settingsObj = record.settings || {};
    if (!settingsObj.pay_schedule) {
      settingsObj.pay_schedule = {
        calculation_method: 'Actual Days',
        fixed_working_days: 26,
        working_hours_per_day: 8.0,
        pay_date_type: 'Last Day',
        pay_date_value: 1,
        first_month: '',
        first_date: null,
        holiday_work_policy: 'Normal Pay',
        holiday_overtime_multiplier: 1.5
      };
      await record.update({ settings: settingsObj });
    } else {
      let updated = false;
      if (settingsObj.pay_schedule.holiday_work_policy === undefined) {
        settingsObj.pay_schedule.holiday_work_policy = 'Normal Pay';
        updated = true;
      }
      if (settingsObj.pay_schedule.holiday_overtime_multiplier === undefined) {
        settingsObj.pay_schedule.holiday_overtime_multiplier = 1.5;
        updated = true;
      }
      if (updated) {
        await record.update({ settings: settingsObj });
      }
    }
    
    return res.json({ success: true, data: settingsObj.pay_schedule });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.savePayrollSettings = async (req, res) => {
  try {
    const { outlet_settings } = req.propertyDb.models;
    const {
      calculation_method,
      fixed_working_days,
      working_hours_per_day,
      pay_date_type,
      pay_date_value,
      first_month,
      first_date,
      holiday_work_policy,
      holiday_overtime_multiplier
    } = req.body;
    
    let record = await outlet_settings.findOne({ where: { outlet_id: req.user.outlet_id } });
    if (!record) {
      record = await outlet_settings.create({
        outlet_id: req.user.outlet_id,
        settings: {}
      });
    }
    
    const settingsObj = record.settings || {};
    settingsObj.pay_schedule = {
      calculation_method: calculation_method || 'Actual Days',
      fixed_working_days: parseInt(fixed_working_days) || 26,
      working_hours_per_day: parseFloat(working_hours_per_day) || 8.0,
      pay_date_type: pay_date_type || 'Last Day',
      pay_date_value: parseInt(pay_date_value) || 1,
      first_month: first_month || '',
      first_date: first_date || null,
      holiday_work_policy: holiday_work_policy || 'Normal Pay',
      holiday_overtime_multiplier: parseFloat(holiday_overtime_multiplier) || 1.5
    };
    
    await record.update({ settings: settingsObj });
    return res.json({ success: true, data: settingsObj.pay_schedule });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.reviseSalary = async (req, res) => {
  const transaction = await req.propertyDb.transaction();
  try {
    const { hr_employees, hr_salary_revisions } = req.propertyDb.models;
    const { id } = req.params;
    const { new_salary, effective_date } = req.body;
    
    const employee = await hr_employees.findOne({
      where: { id, outlet_id: req.user.outlet_id },
      transaction
    });
    if (!employee) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Employee not found' });
    }
    
    const previous_salary = parseFloat(employee.base_salary) || 0.0;
    
    // Create salary revision record with Pending status
    await hr_salary_revisions.create({
      outlet_id: req.user.outlet_id,
      employee_id: employee.id,
      previous_salary,
      new_salary: parseFloat(new_salary),
      effective_date: effective_date || new Date().toISOString().split('T')[0],
      status: 'Pending',
      created_by: req.user.id
    }, { transaction });
    
    await transaction.commit();
    return res.json({ success: true, message: 'Salary revision submitted for approval' });
  } catch (err) {
    await transaction.rollback();
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.addBonus = async (req, res) => {
  try {
    const { hr_employees, hr_arrears } = req.propertyDb.models;
    const { id } = req.params;
    const { amount, reason, payment_month, pay_instantly } = req.body;
    
    const employee = await hr_employees.findOne({
      where: { id, outlet_id: req.user.outlet_id }
    });
    if (!employee) {
      return res.status(404).json({ success: false, message: 'Employee not found' });
    }
    
    // Create arrear/bonus record with Pending Approval status
    const fullReason = `${reason || 'Bonus'} (${pay_instantly === true ? 'Instant' : 'Payroll'})`;
    await hr_arrears.create({
      outlet_id: req.user.outlet_id,
      employee_id: employee.id,
      amount: parseFloat(amount),
      reason: fullReason,
      payment_month: payment_month || new Date().toISOString().slice(0, 7),
      status: 'Pending Approval'
    });
    
    return res.json({ success: true, message: 'Bonus assigned successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.bulkRevise = async (req, res) => {
  const transaction = await req.propertyDb.transaction();
  try {
    const { hr_employees, hr_salary_revisions } = req.propertyDb.models;
    const { type, value, designation_id, employee_ids, effective_date } = req.body;
    
    // Find target employees (designation_id represents Grade / pay_structure_id)
    const where = { status: 'Active', outlet_id: req.user.outlet_id };
    if (employee_ids && employee_ids.length > 0) {
      where.id = employee_ids;
    } else if (designation_id) {
      where.pay_structure_id = designation_id;
    }
    
    const employees = await hr_employees.findAll({ where, transaction });
    if (employees.length === 0) {
      await transaction.rollback();
      return res.status(400).json({ success: false, message: 'No active employees found matching criteria' });
    }
    
    const effective = moment(effective_date || new Date());
    
    for (const emp of employees) {
      const prev_salary = parseFloat(emp.base_salary) || 0.0;
      let new_salary = prev_salary;
      
      if (type === 'Percentage') {
        new_salary = prev_salary * (1 + parseFloat(value) / 100.0);
      } else if (type === 'Amount') {
        new_salary = prev_salary + parseFloat(value);
      }
      
      new_salary = parseFloat(new_salary.toFixed(2));
      
      // Log salary revision with Pending status
      await hr_salary_revisions.create({
        outlet_id: req.user.outlet_id,
        employee_id: emp.id,
        previous_salary: prev_salary,
        new_salary,
        effective_date: effective.format('YYYY-MM-DD'),
        status: 'Pending',
        created_by: req.user.id
      }, { transaction });
    }
    
    await transaction.commit();
    return res.json({ success: true, message: `Salary revisions created for ${employees.length} employee(s) and sent for approval.` });
  } catch (err) {
    await transaction.rollback();
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.bulkBonus = async (req, res) => {
  const transaction = await req.propertyDb.transaction();
  try {
    const { hr_employees, hr_arrears, expenses, expense_categories, cash_ledger } = req.propertyDb.models;
    const { type, value, designation_id, employee_ids, payment_mode, payment_method, reason, payment_month } = req.body;
    
    // Find target employees
    const where = { status: 'Active', outlet_id: req.user.outlet_id };
    if (employee_ids && employee_ids.length > 0) {
      where.id = employee_ids;
    } else if (designation_id) {
      where.pay_structure_id = designation_id;
    }
    
    const employees = await hr_employees.findAll({ where, transaction });
    if (employees.length === 0) {
      await transaction.rollback();
      return res.status(400).json({ success: false, message: 'No active employees found matching criteria' });
    }
    
    const targetMonth = payment_month || moment().format('YYYY-MM');
    const isInstant = payment_mode === 'Instant';
    const method = payment_method || 'Cash';
    const fullReason = `${reason || 'Bonus'} (${isInstant ? 'Instant' : 'Payroll'})`;
    
    let totalBonusPaid = 0.0;
    const createdBonuses = [];

    for (const emp of employees) {
      const base = parseFloat(emp.base_salary) || 0.0;
      let amount = 0.0;
      
      if (type === 'Percentage') {
        amount = base * (parseFloat(value) / 100.0);
      } else if (type === 'Amount') {
        amount = parseFloat(value);
      }
      
      amount = parseFloat(amount.toFixed(2));
      totalBonusPaid += amount;
      
      const bon = await hr_arrears.create({
        outlet_id: req.user.outlet_id,
        employee_id: emp.id,
        amount,
        reason: fullReason,
        payment_month: targetMonth,
        status: isInstant ? 'Paid' : 'Pending Approval'
      }, { transaction });
      
      createdBonuses.push(bon);
    }

    // If Instant payment, write to expenses and cash ledger immediately
    if (isInstant && totalBonusPaid > 0) {
      let categoryId = null;
      if (expenses && expense_categories) {
        const [category] = await expense_categories.findOrCreate({
          where: { category_name: 'Salaries & Wages', outlet_id: req.user.outlet_id },
          defaults: { category_name: 'Salaries & Wages', user_id: req.user.id },
          transaction
        });
        categoryId = category.id;
        
        await expenses.create({
          category_id: categoryId,
          base_amount: totalBonusPaid,
          net_payable_amount: totalBonusPaid,
          payment_date: new Date(),
          expense_note: `Instant Bulk Bonus payout: ${reason || 'Bonus'} for ${employees.length} employees`,
          payment_method: method,
          status: 'Paid',
          outlet_id: req.user.outlet_id,
          created_by: req.user.id
        }, { transaction });
      }
      
      if (cash_ledger) {
        await cash_ledger.create({
          outlet_id: req.user.outlet_id,
          txn_date: moment().format('YYYY-MM-DD'),
          transaction_type: 'EXPENSE',
          reference_type: 'BONUS',
          reference_id: createdBonuses[0]?.id?.toString() || 'BULK',
          reference_no: `BONUS-${targetMonth}-${moment().format('X')}`,
          party_name: 'Salaries & Wages',
          payment_method: method,
          notes: `Instant Bulk Bonus payout: ${reason || 'Bonus'} for ${employees.length} employees`,
          amount_out: totalBonusPaid,
          amount_in: 0,
          created_by: req.user.id
        }, { transaction });
      }
    }
    
    await transaction.commit();
    return res.json({ 
      success: true, 
      message: isInstant
        ? `Instant Bonuses of ₹${totalBonusPaid.toFixed(2)} paid and debited from ledger for ${employees.length} employee(s).`
        : `Bonuses created for ${employees.length} employee(s) and sent for approval.` 
    });
  } catch (err) {
    await transaction.rollback();
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getRevisions = async (req, res) => {
  try {
    const { hr_salary_revisions, hr_employees } = req.propertyDb.models;
    const data = await hr_salary_revisions.findAll({
      where: { outlet_id: req.user.outlet_id },
      include: [{ model: hr_employees, as: 'employee', attributes: ['id', 'full_name', 'employee_code'] }],
      order: [['id', 'DESC']]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getBonuses = async (req, res) => {
  try {
    const { hr_arrears, hr_employees } = req.propertyDb.models;
    const data = await hr_arrears.findAll({
      where: { outlet_id: req.user.outlet_id },
      include: [{ model: hr_employees, as: 'employee', attributes: ['id', 'full_name', 'employee_code'] }],
      order: [['id', 'DESC']]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getApprovals = async (req, res) => {
  try {
    const { hr_leave_applications, hr_loans, hr_employees, hr_leave_types, hr_salary_revisions, hr_arrears } = req.propertyDb.models;
    
    const leaves = await hr_leave_applications.findAll({
      where: { outlet_id: req.user.outlet_id },
      include: [
        { model: hr_employees, as: 'employee', attributes: ['id', 'full_name', 'employee_code'] },
        { model: hr_leave_types, as: 'leaveType', attributes: ['id', 'name'] }
      ],
      order: [['id', 'DESC']]
    });
    
    const loans = await hr_loans.findAll({
      where: { outlet_id: req.user.outlet_id },
      include: [{ model: hr_employees, as: 'employee', attributes: ['id', 'full_name', 'employee_code'] }],
      order: [['id', 'DESC']]
    });

    const revisions = await hr_salary_revisions.findAll({
      where: { outlet_id: req.user.outlet_id, status: 'Pending' },
      include: [{ model: hr_employees, as: 'employee', attributes: ['id', 'full_name', 'employee_code'] }],
      order: [['id', 'DESC']]
    });

    const bonuses = await hr_arrears.findAll({
      where: { outlet_id: req.user.outlet_id, status: 'Pending Approval' },
      include: [{ model: hr_employees, as: 'employee', attributes: ['id', 'full_name', 'employee_code'] }],
      order: [['id', 'DESC']]
    });
    
    return res.json({
      success: true,
      data: { leaves, loans, revisions, bonuses }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getEmployeeRevisions = async (req, res) => {
  try {
    const { hr_salary_revisions } = req.propertyDb.models;
    const { id } = req.params;
    const data = await hr_salary_revisions.findAll({
      where: { employee_id: id, outlet_id: req.user.outlet_id },
      order: [['id', 'DESC']]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getEmployeeBonuses = async (req, res) => {
  try {
    const { hr_arrears } = req.propertyDb.models;
    const { id } = req.params;
    const data = await hr_arrears.findAll({
      where: { employee_id: id, outlet_id: req.user.outlet_id },
      order: [['id', 'DESC']]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.approveRevision = async (req, res) => {
  const transaction = await req.propertyDb.transaction();
  try {
    const { hr_salary_revisions, hr_employees } = req.propertyDb.models;
    const { id } = req.params;
    
    const rev = await hr_salary_revisions.findOne({
      where: { id, outlet_id: req.user.outlet_id },
      transaction
    });
    if (!rev) {
      await transaction.rollback();
      return res.status(404).json({ success: false, message: 'Salary revision not found' });
    }
    
    rev.status = 'Approved';
    rev.approved_by = req.user.id;
    await rev.save({ transaction });
    
    // Update employee base salary
    const emp = await hr_employees.findOne({
      where: { id: rev.employee_id, outlet_id: req.user.outlet_id },
      transaction
    });
    if (emp) {
      await emp.update({ base_salary: rev.new_salary }, { transaction });
    }
    
    await transaction.commit();
    return res.json({ success: true, message: 'Salary revision approved successfully' });
  } catch (err) {
    await transaction.rollback();
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.rejectRevision = async (req, res) => {
  try {
    const { hr_salary_revisions } = req.propertyDb.models;
    const { id } = req.params;
    const [updated] = await hr_salary_revisions.update(
      { status: 'Rejected', approved_by: req.user.id },
      { where: { id, outlet_id: req.user.outlet_id } }
    );
    if (!updated) return res.status(404).json({ success: false, message: 'Salary revision not found' });
    return res.json({ success: true, message: 'Salary revision rejected' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.approveBonus = async (req, res) => {
  try {
    const { hr_arrears, hr_employees, expenses, expense_categories, cash_ledger } = req.propertyDb.models;
    const { id } = req.params;
    
    const bon = await hr_arrears.findOne({
      where: { id, outlet_id: req.user.outlet_id },
      include: [{ model: hr_employees, as: 'employee' }]
    });
    if (!bon) return res.status(404).json({ success: false, message: 'Bonus not found' });
    
    // Check if it is an instant payment or a monthly payroll cycle payout
    const isInstant = bon.reason && bon.reason.includes('(Instant)');
    bon.status = isInstant ? 'Paid' : 'Pending';
    await bon.save();

    if (isInstant) {
      const amount = parseFloat(bon.amount) || 0.0;
      if (amount > 0) {
        let categoryId = null;
        if (expenses && expense_categories) {
          const [category] = await expense_categories.findOrCreate({
            where: { category_name: 'Salaries & Wages', outlet_id: req.user.outlet_id },
            defaults: { category_name: 'Salaries & Wages', user_id: req.user.id }
          });
          categoryId = category.id;
          
          await expenses.create({
            category_id: categoryId,
            base_amount: amount,
            net_payable_amount: amount,
            payment_date: new Date(),
            expense_note: `Instant Bonus paid to ${bon.employee?.full_name} (${bon.employee?.employee_code}): ${bon.reason}`,
            payment_method: 'Cash',
            status: 'Paid',
            outlet_id: req.user.outlet_id,
            created_by: req.user.id
          });
        }
        
        if (cash_ledger) {
          await cash_ledger.create({
            outlet_id: req.user.outlet_id,
            txn_date: moment().format('YYYY-MM-DD'),
            transaction_type: 'EXPENSE',
            reference_type: 'BONUS',
            reference_id: bon.id.toString(),
            reference_no: `BONUS-${bon.id}`,
            party_name: 'Salaries & Wages',
            payment_method: 'Cash',
            notes: `Instant Bonus paid to ${bon.employee?.full_name} (${bon.employee?.employee_code}): ${bon.reason}`,
            amount_out: amount,
            amount_in: 0,
            created_by: req.user.id
          });
        }
      }
    }
    
    return res.json({ success: true, message: 'Bonus approved successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.rejectBonus = async (req, res) => {
  try {
    const { hr_arrears } = req.propertyDb.models;
    const { id } = req.params;
    const [updated] = await hr_arrears.update(
      { status: 'Rejected' },
      { where: { id, outlet_id: req.user.outlet_id } }
    );
    if (!updated) return res.status(404).json({ success: false, message: 'Bonus not found' });
    return res.json({ success: true, message: 'Bonus rejected' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// ==================== HOLIDAYS ====================

exports.getHolidays = async (req, res) => {
  try {
    const { hr_holidays } = req.propertyDb.models;
    const data = await hr_holidays.findAll({
      where: { outlet_id: req.user.outlet_id },
      order: [['holiday_date', 'ASC']]
    });
    return res.json({ success: true, data });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createHoliday = async (req, res) => {
  try {
    const { hr_holidays, hr_employees, hr_attendance_punches, hr_payroll_runs } = req.propertyDb.models;
    const { name, holiday_date, is_recurring } = req.body;

    const monthStr = moment(holiday_date).format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && monthStr <= latestLockedRun.pay_period) {
      return res.status(400).json({ success: false, message: `Holiday creation is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }
    
    // 1. Create holiday record
    const holiday = await hr_holidays.create({
      outlet_id: req.user.outlet_id,
      name,
      holiday_date,
      is_recurring: !!is_recurring
    });

    // 2. Batch mark attendance as Holiday for all active employees on that date
    const employees = await hr_employees.findAll({
      where: { outlet_id: req.user.outlet_id, status: 'Active' }
    });

    for (const emp of employees) {
      const existing = await hr_attendance_punches.findOne({
        where: { employee_id: emp.id, punch_date: holiday_date }
      });

      if (existing) {
        if (existing.status === 'Absent') {
          await existing.update({
            status: 'Holiday',
            hours_worked: 0.0,
            overtime_hours: 0.0,
            lateness_mins: 0
          });
        }
      } else {
        await hr_attendance_punches.create({
          outlet_id: req.user.outlet_id,
          employee_id: emp.id,
          punch_date: holiday_date,
          status: 'Holiday',
          hours_worked: 0.0,
          overtime_hours: 0.0,
          lateness_mins: 0,
          punch_source: 'System'
        });
      }
    }

    return res.json({ success: true, data: holiday });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteHoliday = async (req, res) => {
  try {
    const { hr_holidays, hr_attendance_punches, hr_payroll_runs } = req.propertyDb.models;
    const { id } = req.params;

    const holiday = await hr_holidays.findOne({
      where: { id, outlet_id: req.user.outlet_id }
    });
    if (!holiday) return res.status(404).json({ success: false, message: 'Holiday not found' });

    const monthStr = moment(holiday.holiday_date).format('YYYY-MM');
    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && monthStr <= latestLockedRun.pay_period) {
      return res.status(400).json({ success: false, message: `Holiday deletion is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }

    const dateStr = holiday.holiday_date;

    await holiday.destroy();

    // Revert/delete the System-created Holiday punches for this date
    await hr_attendance_punches.destroy({
      where: {
        outlet_id: req.user.outlet_id,
        punch_date: dateStr,
        status: 'Holiday',
        punch_source: 'System'
      }
    });

    return res.json({ success: true, message: 'Holiday deleted and attendance reverted successfully' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.autoWeeklyOffs = async (req, res) => {
  try {
    const { hr_employees, hr_shifts, hr_attendance_punches, hr_payroll_runs } = req.propertyDb.models;
    const { month } = req.body;
    if (!month) {
      return res.status(400).json({ success: false, message: 'Month (YYYY-MM) is required' });
    }

    const latestLockedRun = await hr_payroll_runs.findOne({
      where: { status: 'Approved', outlet_id: req.user.outlet_id },
      order: [['pay_period', 'DESC']]
    });
    if (latestLockedRun && month <= latestLockedRun.pay_period) {
      return res.status(400).json({ success: false, message: `Weekly offs generation is locked. Payroll for ${latestLockedRun.pay_period} (or a later month) has already been approved and paid!` });
    }

    const startDate = moment(month, 'YYYY-MM').startOf('month');
    const endDate = moment(month, 'YYYY-MM').endOf('month');
    const daysInMonth = startDate.daysInMonth();

    const employees = await hr_employees.findAll({
      where: { outlet_id: req.user.outlet_id, status: 'Active' },
      include: [{ model: hr_shifts, as: 'shift' }]
    });

    let createdCount = 0;
    let updatedCount = 0;

    for (const emp of employees) {
      const shift = emp.shift || {};
      const weeklyOffs = shift.weekly_offs || ["Sunday"];

      for (let day = 1; day <= daysInMonth; day++) {
        const currentDate = moment(month, 'YYYY-MM').date(day);
        const dateStr = currentDate.format('YYYY-MM-DD');
        const dayName = currentDate.format('dddd');

        let isOff = false;
        if (weeklyOffs.includes(dayName)) {
          isOff = true;
        } else if (dayName === 'Saturday') {
          let satCount = 0;
          for (let d = 1; d <= day; d++) {
            if (moment(month, 'YYYY-MM').date(d).day() === 6) {
              satCount++;
            }
          }
          const checkStr = `${satCount}${satCount === 1 ? 'st' : satCount === 2 ? 'nd' : satCount === 3 ? 'rd' : 'th'} Saturday`;
          if (weeklyOffs.includes(checkStr)) {
            isOff = true;
          }
        }

        if (isOff) {
          const existing = await hr_attendance_punches.findOne({
            where: { employee_id: emp.id, punch_date: dateStr }
          });

          if (!existing) {
            await hr_attendance_punches.create({
              outlet_id: req.user.outlet_id,
              employee_id: emp.id,
              punch_date: dateStr,
              status: 'Weekly Off',
              hours_worked: 0.0,
              overtime_hours: 0.0,
              lateness_mins: 0,
              punch_source: 'System'
            });
            createdCount++;
          } else if (existing.status === 'Absent') {
            await existing.update({
              status: 'Weekly Off',
              hours_worked: 0.0,
              overtime_hours: 0.0,
              lateness_mins: 0
            });
            updatedCount++;
          }
        }
      }
    }

    return res.json({
      success: true,
      message: `Weekly offs processed: ${createdCount} created, ${updatedCount} updated.`
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.payPayrollDetails = async (req, res) => {
  try {
    const { detail_ids, payment_methods } = req.body;
    const { hr_payroll_runs, hr_payroll_details, expenses, expense_categories, cash_ledger, hr_employees } = req.propertyDb.models;
    
    if (!detail_ids || !Array.isArray(detail_ids)) {
      return res.status(400).json({ success: false, message: 'detail_ids array is required' });
    }

    const results = [];
    
    for (const detailId of detail_ids) {
      const detail = await hr_payroll_details.findOne({
        where: { id: detailId },
        include: [
          { model: hr_payroll_runs, as: 'payrollRun' },
          { model: hr_employees, as: 'employee' }
        ]
      });
      
      if (!detail) continue;
      
      const breakdown = detail.components_breakdown || {};
      const currentStatus = breakdown.payment_status || 'Unpaid';
      
      if (currentStatus === 'Paid') {
        continue; // already paid
      }
      if (currentStatus === 'On Hold' || currentStatus === 'Hold') {
        return res.status(400).json({ success: false, message: `Payment for ${detail.employee?.full_name} is on hold. Please release hold first.` });
      }
      
      const method = (payment_methods && payment_methods[detailId.toString()]) || 'Cash';
      
      // Update breakdown status
      breakdown.payment_status = 'Paid';
      breakdown.payment_method = method;
      detail.components_breakdown = breakdown;
      detail.changed('components_breakdown', true);
      await detail.save();
      
      // Log Expense
      let categoryId = null;
      if (expenses && expense_categories) {
        const [category] = await expense_categories.findOrCreate({
          where: { category_name: 'Salaries & Wages', outlet_id: req.user.outlet_id },
          defaults: { category_name: 'Salaries & Wages', user_id: req.user.id }
        });
        categoryId = category.id;
        
        await expenses.create({
          category_id: categoryId,
          base_amount: detail.net_pay,
          net_payable_amount: detail.net_pay,
          payment_date: new Date(),
          expense_note: `Salary paid to ${detail.employee?.full_name} (${detail.employee?.employee_code}) for ${detail.payrollRun?.pay_period}`,
          payment_method: method,
          status: 'Paid',
          outlet_id: req.user.outlet_id,
          created_by: req.user.id
        });
      }
      
      // Log Cash Ledger
      if (cash_ledger) {
        await cash_ledger.create({
          outlet_id: req.user.outlet_id,
          txn_date: moment().format('YYYY-MM-DD'),
          transaction_type: 'EXPENSE',
          reference_type: 'PAYROLL',
          reference_id: detail.payrollRun?.id?.toString(),
          reference_no: `PAYROLL-${detail.payrollRun?.pay_period}-${detail.employee?.employee_code}`,
          party_name: 'Salaries & Wages',
          payment_method: method,
          notes: `Salary paid to ${detail.employee?.full_name} (${detail.employee?.employee_code}) for ${detail.payrollRun?.pay_period}`,
          amount_out: detail.net_pay,
          amount_in: 0,
          created_by: req.user.id
        });
      }
      
      results.push(detailId);
    }
    
    return res.json({ success: true, message: 'Payments processed successfully', data: results });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.togglePayrollDetailHold = async (req, res) => {
  try {
    const { id } = req.params;
    const { hr_payroll_details } = req.propertyDb.models;
    
    const detail = await hr_payroll_details.findOne({ where: { id } });
    if (!detail) return res.status(404).json({ success: false, message: 'Payroll detail not found' });
    
    const breakdown = detail.components_breakdown || {};
    const currentStatus = breakdown.payment_status || 'Unpaid';
    
    if (currentStatus === 'Paid') {
      return res.status(400).json({ success: false, message: 'Cannot put a paid salary on hold!' });
    }
    
    breakdown.payment_status = (currentStatus === 'On Hold') ? 'Unpaid' : 'On Hold';
    detail.components_breakdown = breakdown;
    detail.changed('components_breakdown', true);
    await detail.save();
    
    return res.json({ success: true, message: 'Status updated successfully', data: breakdown.payment_status });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
