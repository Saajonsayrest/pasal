import type { Role } from './types'

export interface NavItem {
  key: string
  href: string
  icon: string
  en: string
  ne: string
  ownerOnly?: boolean
}

export interface NavGroup {
  label?: { en: string; ne: string }
  ownerOnly?: boolean
  items: NavItem[]
}

/** Phone bottom menu: 5 buttons. "sell" is the big middle one. */
export const bottomNav: NavItem[] = [
  { key: 'home', href: '/', icon: 'home', en: 'Home', ne: 'गृह' },
  { key: 'items', href: '/items', icon: 'inventory_2', en: 'Items', ne: 'सामान' },
  { key: 'sell', href: '/sell', icon: 'add_shopping_cart', en: 'Sell', ne: 'बेच्ने' },
  { key: 'customers', href: '/customers', icon: 'group', en: 'Customers', ne: 'ग्राहक' },
  { key: 'more', href: '/more', icon: 'menu', en: 'More', ne: 'थप' },
]

/** Side menu on wide screens (website and Mac app). */
export const sideNav: NavGroup[] = [
  {
    label: { en: 'Main', ne: 'मुख्य' },
    items: [
      { key: 'home', href: '/', icon: 'home', en: 'Home', ne: 'गृहपृष्ठ' },
      { key: 'sales', href: '/sales', icon: 'receipt', en: 'Sales', ne: 'बिक्री' },
      { key: 'items', href: '/items', icon: 'inventory_2', en: 'Items', ne: 'सामान' },
      { key: 'customers', href: '/customers', icon: 'group', en: 'Customers', ne: 'ग्राहक' },
      { key: 'notifications', href: '/notifications', icon: 'notifications', en: 'Notifications', ne: 'सूचना' },
    ],
  },
  {
    label: { en: 'Stock', ne: 'स्टक' },
    ownerOnly: true,
    items: [
      { key: 'stock-count', href: '/stock-count', icon: 'fact_check', en: 'Stock count', ne: 'स्टक गणना', ownerOnly: true },
      { key: 'low-stock', href: '/low-stock', icon: 'production_quantity_limits', en: 'Low stock', ne: 'कम स्टक', ownerOnly: true },
      { key: 'categories', href: '/categories', icon: 'category', en: 'Categories', ne: 'वर्ग', ownerOnly: true },
    ],
  },
  {
    label: { en: 'Buying', ne: 'खरिद' },
    ownerOnly: true,
    items: [
      { key: 'purchases', href: '/purchases', icon: 'shopping_bag', en: 'Purchases', ne: 'खरिद', ownerOnly: true },
      { key: 'suppliers', href: '/suppliers', icon: 'local_shipping', en: 'Suppliers', ne: 'डिलर', ownerOnly: true },
    ],
  },
  {
    label: { en: 'Money', ne: 'पैसा' },
    ownerOnly: true,
    items: [
      { key: 'expenses', href: '/expenses', icon: 'payments', en: 'Expenses', ne: 'खर्च', ownerOnly: true },
      { key: 'cash-book', href: '/cash-book', icon: 'account_balance_wallet', en: 'Cash book', ne: 'नगद किताब', ownerOnly: true },
      { key: 'payments', href: '/payments', icon: 'swap_vert', en: 'All payments', ne: 'सबै भुक्तानी', ownerOnly: true },
    ],
  },
  {
    label: { en: 'Insights', ne: 'विश्लेषण' },
    ownerOnly: true,
    items: [
      { key: 'reports', href: '/reports', icon: 'insights', en: 'Reports', ne: 'रिपोर्ट', ownerOnly: true },
      { key: 'vat', href: '/vat', icon: 'receipt_long', en: 'VAT', ne: 'भ्याट', ownerOnly: true },
    ],
  },
  {
    label: { en: 'Settings', ne: 'सेटिङ' },
    items: [
      { key: 'shop', href: '/settings/shop', icon: 'storefront', en: 'Shop details', ne: 'पसल विवरण', ownerOnly: true },
      { key: 'staff', href: '/settings/staff', icon: 'badge', en: 'Staff', ne: 'कर्मचारी', ownerOnly: true },
      { key: 'activity', href: '/settings/activity', icon: 'history', en: 'Activity log', ne: 'गतिविधि लग', ownerOnly: true },
      { key: 'look', href: '/settings/look', icon: 'palette', en: 'App look', ne: 'एपको रूप' },
    ],
  },
]

export const canSee = (item: { ownerOnly?: boolean }, role: Role | undefined): boolean => !item.ownerOnly || role === 'owner'
