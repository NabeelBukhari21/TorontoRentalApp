-- Returned-payment charges.
--
-- Ontario landlords can't charge late fees on rent (RTA s. 134). The one
-- allowed charge is an administration fee for a returned (NSF) cheque or
-- debit, capped at $20 plus the bank's own charges. 'late_fee' stays in
-- the enum so existing rows decode, but nothing should create it.

alter type payment_kind add value if not exists 'nsf_fee';

comment on type payment_kind is
  'late_fee is retained for old rows only; Ontario prohibits late fees on rent. Use nsf_fee (max $20) for returned payments.';
