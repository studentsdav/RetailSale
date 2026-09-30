export interface IsBankPaymentMethodParams {
  db: any;
  method?: string;
}

export interface BankBalanceParams {
  db: any;
  outlet_id: number | string;
  amount: number | string;
  bankAccountId?: number | string | null;
  transaction?: any;
}

export interface DefaultBankAccountParams {
  db: any;
  outlet_id: number | string;
  transaction?: any;
}

/**
 * Fetches active payment method names dynamically from payment_methods master table
 */
export async function getAllActivePaymentMethods(db: any): Promise<string[]> {
  if (!db || !db.models || !db.models.payment_methods) return [];
  try {
    const list = await db.models.payment_methods.findAll({
      where: { is_active: true },
      attributes: ['name'],
      raw: true
    });
    return list.map((pm: any) => String(pm.name).trim().toUpperCase());
  } catch (e) {
    console.error('Error fetching payment_methods master:', e);
    return [];
  }
}

/**
 * Synchronous pattern check fallback
 */
export function isBankPayment(method?: string): boolean {
  if (!method) return false;
  const m = String(method).trim().toUpperCase();
  if (m === 'CASH' || m === 'CREDIT' || m === 'DUE' || m === 'WAIVE_OFF') return false;
  return (
    [
      'CARD',
      'UPI',
      'BANK',
      'BANK_TRANSFER',
      'ONLINE',
      'NETBANKING',
      'CHEQUE',
      'WALLET',
      'POS_CARD',
      'POS_UPI',
      'RAZORPAY',
      'STRIPE',
      'PAYTM',
      'PHONEPE',
      'GPAY',
      'SUBSCRIPTION'
    ].includes(m) ||
    m.includes('BANK') ||
    m.includes('CARD') ||
    m.includes('UPI') ||
    m.includes('ONLINE') ||
    m.includes('TRANSFER') ||
    m.includes('CHEQUE') ||
    m.includes('PAY')
  );
}

/**
 * Async check using payment_methods master table
 */
export async function isBankPaymentMethod({ db, method }: IsBankPaymentMethodParams): Promise<boolean> {
  if (!method) return false;
  const m = String(method).trim().toUpperCase();

  if (['CASH', 'CREDIT', 'DUE', 'WAIVE_OFF'].includes(m)) return false;

  if (db) {
    const masterMethods = await getAllActivePaymentMethods(db);
    if (masterMethods.length > 0) {
      const found = masterMethods.includes(m);
      if (found && !['CASH', 'CREDIT', 'DUE', 'WAIVE_OFF'].includes(m)) {
        return true;
      }
    }
  }

  return isBankPayment(method);
}

export async function getDefaultBankAccount({ db, outlet_id, transaction }: DefaultBankAccountParams): Promise<any> {
  let bank = await db.models.bank_accounts.findOne({
    where: { outlet_id, is_active: true, is_primary: true },
    transaction
  });

  if (!bank) {
    bank = await db.models.bank_accounts.findOne({
      where: { outlet_id, is_active: true },
      order: [['id', 'ASC']],
      transaction
    });
  }

  if (!bank) {
    bank = await db.models.bank_accounts.create(
      {
        outlet_id,
        bank_name: 'Main Bank Account',
        account_name: 'Primary Bank Account (Card/UPI/Bank)',
        account_number: 'DEFAULT-BANK-01',
        account_type: 'CURRENT',
        opening_balance: 0,
        current_balance: 0,
        is_active: true
      },
      { transaction }
    );
  }
  return bank;
}

export async function creditBankBalance({
  db,
  outlet_id,
  amount,
  bankAccountId = null,
  transaction = undefined
}: BankBalanceParams): Promise<any> {
  const amt = Number(amount) || 0;
  if (amt <= 0) return;

  let bank: any;
  if (bankAccountId) {
    bank = await db.models.bank_accounts.findOne({ where: { id: bankAccountId, outlet_id }, transaction });
  }
  if (!bank) {
    bank = await getDefaultBankAccount({ db, outlet_id, transaction });
  }
  if (bank) {
    const newBalance = Number((Number(bank.current_balance || 0) + amt).toFixed(2));
    await bank.update({ current_balance: newBalance }, { transaction });
  }
  return bank;
}

export async function debitBankBalance({
  db,
  outlet_id,
  amount,
  bankAccountId = null,
  transaction = undefined
}: BankBalanceParams): Promise<any> {
  const amt = Number(amount) || 0;
  if (amt <= 0) return;

  let bank: any;
  if (bankAccountId) {
    bank = await db.models.bank_accounts.findOne({ where: { id: bankAccountId, outlet_id }, transaction });
  }
  if (!bank) {
    bank = await getDefaultBankAccount({ db, outlet_id, transaction });
  }
  if (bank) {
    const newBalance = Number((Number(bank.current_balance || 0) - amt).toFixed(2));
    await bank.update({ current_balance: newBalance }, { transaction });
  }
  return bank;
}

module.exports = {
  getAllActivePaymentMethods,
  isBankPayment,
  isBankPaymentMethod,
  getDefaultBankAccount,
  creditBankBalance,
  debitBankBalance
};
