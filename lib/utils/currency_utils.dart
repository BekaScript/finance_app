// Create a new file for currency utilities
String getCurrencySymbol(String currency) {
  switch (currency) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'INR':
      return '₹';
    case 'KGS':
      return 'с';
    default:
      return '\$';
  }
} 