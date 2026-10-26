// Shapes of the PASAL API (docs/api-reference.md). Money is whole paisa. Dates are ISO strings.

export type Role = 'owner' | 'staff'

export interface Business {
  id: number
  name: string
  pan: string | null
  phone: string | null
  address: string | null
  vat_rate: number
}

export interface User {
  id: number
  name: string
  email: string
  role: Role
  business?: Business
}

export interface Category {
  id: number
  name: string
  icon: string | null
  color: string | null
}

export interface Item {
  id: number
  category_id: number | null
  name: string
  sku: string | null
  unit: string
  vat_applies: boolean
  cost_price: number | null // null for staff
  sell_price: number
  quantity: number
  low_stock_at: number
  is_low_stock: boolean
  photo_url: string | null
}

export interface Customer {
  id: number
  name: string
  phone: string | null
  address: string | null
  pan: string | null
  credit_limit: number | null
  // Present on GET /customers and GET /customers/{id} (not inside a sale).
  owes?: number
  last_sale_at?: string | null
  oldest_unpaid_at?: string | null
}

export interface Supplier {
  id: number
  name: string
  phone: string | null
  address: string | null
  pan: string | null
  note: string | null
  // Present on GET /suppliers and GET /suppliers/{id} (not inside a purchase).
  we_owe?: number
  last_purchase_at?: string | null
}

export interface SaleLine {
  id: number
  item_id: number
  item_name: string
  quantity: number
  unit_price: number
  discount: number
  line_total: number
  returned_quantity: number
}

export interface Payment {
  id: number
  direction: 'in' | 'out' | 'refund'
  sale_id: number | null
  purchase_id: number | null
  amount: number
  method: string
  paid_at: string
  party?: string | null
}

export interface SaleReturn {
  id: number
  sale_id: number
  kind: 'return' | 'cancel'
  returned_at: string
  total: number
  vat_amount: number
  refunded: number
  restocked: boolean
  note: string | null
  items: { sale_item_id: number; quantity: number; amount: number }[]
}

export interface Sale {
  id: number
  bill_no: string | null
  customer_id: number | null
  customer: Customer | null
  subtotal: number
  discount: number
  total: number
  returned_total: number
  paid: number
  balance: number
  cancelled_at: string | null
  vat_rate: number
  taxable_amount: number
  vat_amount: number
  exempt_amount: number
  sold_at: string
  note: string | null
  /** Name of the person who made the sale (GET /sales and GET /sales/{id}). */
  sold_by?: string | null
  items?: SaleLine[]
  payments?: Payment[]
  returns?: SaleReturn[]
}

export interface PurchaseLine {
  item_id: number
  item_name: string
  quantity: number
  unit_cost: number
  line_total: number
}

export interface Purchase {
  id: number
  bill_no: string | null
  bill_date: string | null
  supplier_id: number
  supplier: Supplier | null
  total: number
  paid: number
  balance: number
  vat_amount: number
  bought_at: string
  note: string | null
  items?: PurchaseLine[]
  payments?: Payment[]
}

export interface Expense {
  id: number
  title: string
  category: string | null
  amount: number
  spent_at: string
}

export interface VatPreview {
  period_from: string
  period_to: string
  due_date: string
  vat_rate: number
  sales_bills: number
  sales_taxable: number
  sales_exempt: number
  output_vat: number
  purchase_bills_with_vat: number
  purchases_taxable: number
  input_vat: number
  carry_in: number
  payable: number
  carry_out: number
  carry_in_source: string
}

export interface VatFiling {
  id: number
  period: string
  period_from: string
  period_to: string
  source: 'computed' | 'manual'
  sales_taxable: number
  sales_exempt: number
  output_vat: number
  purchases_taxable: number
  input_vat: number
  carry_in: number
  payable: number
  carry_out: number
  filed_on: string | null
  paid_amount: number
  paid_on: string | null
  receipt_no: string | null
  note: string | null
}

export interface Summary {
  from: string
  to: string
  sales_total: number
  vat_collected: number
  cost_of_goods: number
  expenses_total: number
  profit: number
  stock_value: number
  owed_to_us: number
  we_owe: number
}

export interface CustomerLedger {
  customer: Customer
  total_sales: number
  total_paid: number
  owes: number
  credit_limit: number | null
  sales: { id: number; bill_no: string | null; sold_at: string; total: number; returned_total: number; paid: number; balance: number; cancelled_at: string | null }[]
  /** Money in and refunds for this customer, newest first. */
  payments: Payment[]
}

export interface SupplierLedger {
  supplier: Supplier
  total_purchases: number
  total_paid: number
  we_owe: number
  purchases: { id: number; bill_no: string | null; bought_at: string; total: number; paid: number; balance: number }[]
  /** Money paid to this supplier, newest first. */
  payments: Payment[]
}

export interface StockMovement {
  id: number
  change: number
  reason: 'sale' | 'sale_return' | 'sale_cancel' | 'purchase' | 'adjust' | 'count'
  ref_type: 'sale' | 'purchase' | null
  ref_id: number | null
  note: string | null
  by: string | null
  at: string
}

export interface CashBook {
  from: string
  to: string
  opening_balance: number
  money_in: number
  money_out: number
  closing_balance: number
  data: { kind: 'payment_in' | 'payment_out' | 'refund' | 'expense'; id: number; at: string; amount: number; method: string; label: string | null; balance: number }[]
  meta: Meta
}

export interface DailyReport {
  from: string
  to: string
  days: { date: string; bills: number; sales: number }[]
  hours: { hour: number; bills: number; sales: number }[]
  total: number
  bills: number
}

export interface ItemsReport {
  from: string
  to: string
  top: { item_id: number; name: string; unit: string; quantity: number; revenue: number }[]
  slow: { item_id: number; name: string; unit: string; in_stock: number; sold: number; stock_value: number }[]
}

export interface CreditAge {
  as_of: string
  total: number
  buckets: { key: string; label: string; bills: number; amount: number }[]
  customers: { customer_id: number; name: string | null; phone: string | null; owes: number; oldest_days: number; bucket: string }[]
}

export interface StaffReport {
  from: string
  to: string
  data: { user_id: number | null; name: string; bills: number; sales: number; discount: number }[]
}

export interface AppNotification {
  type: 'low_stock' | 'credit_overdue' | 'vat_unfiled' | 'staff_added'
  title: string
  body: string
  at: string
  count?: number
  amount?: number
  due_date?: string
}

export interface ActivityEntry {
  kind: string
  ref_id: number
  at: string
  by: string | null
  label: string | null
  amount: number
}

export interface CustomerSummary {
  owed_total: number
  owing_customers: number
}

export interface Meta {
  current_page: number
  last_page?: number
  per_page: number
  total: number
}

export interface Paged<T> {
  data: T[]
  meta: Meta
  links?: { next: string | null; prev: string | null }
}
