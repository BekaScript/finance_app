// A utility function that converts currency codes to their respective symbols
String getCurrencySymbol(String currencyCode) {
  // Simple mapping of currency codes to their symbols
  Map<String, String> symbols = {
    'USD': '\$',    // US Dollar
    'EUR': '€',     // Euro
    'GBP': '£',     // British Pound
    'KGS': 'сом',   // Kyrgyz Som
    'RUB': '₽',     // Russian Ruble
    'INR': '₹',     // Indian Rupee
  };
  
  // Return the symbol if it exists in our map, otherwise return the currency code itself
  return symbols[currencyCode] ?? currencyCode;
} 