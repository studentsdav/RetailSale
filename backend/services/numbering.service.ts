export const getNextNumber = async (
  db: any,
  outlet_id: number | string,
  module: string
): Promise<string> => {
  const setting = await db.models.numbering_settings.findOne({
    where: { outlet_id, module }
  });

  if (!setting) throw new Error('Numbering not configured');

  const startNo = Math.max(1, Math.round(Number(setting.start_no) || 1));
  const lastUsedNo = Math.round(Number(setting.last_used_no) || 0);
  const nextNo = lastUsedNo === 0 ? startNo : lastUsedNo + 1;

  const finalNo = `${setting.prefix || ''}${nextNo}${setting.postfix || ''}`;

  await setting.update({ last_used_no: nextNo });

  return finalNo;
};

module.exports = {
  getNextNumber
};
