#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#property strict
input double AccountSize = 10000.00;  // Account Size
input double RiskPercent = 2.0;       // Risk percentage per trade
input double MaxDailyLoss = 2.0;      // Maximum daily loss in percentage
input double MaxDrawdown = 5.0;       // Maximum drawdown in percentage
input bool UseTrendFilter = true;     // Use trend filter for entries
input int AvoidNewsMinutes = 5;      // Minutes before and after news to avoid trading
input double ATRMultiplier = 1.5;     // Multiplier for ATR-based stop-loss
input int MovingAveragePeriod = 50;   // Moving Average period for trend filter
input double LotSize = 0.1;           // Fixed lot size (if RiskPercent is 0)
input int MaxTradesPerDay = 5;        // Maximum trades allowed per day

// Global variables
CTrade trade;
double accountEquityAtStart;
double dailyLoss;
double maxEquity;
int tradesToday;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   accountEquityAtStart = AccountInfoDouble(ACCOUNT_EQUITY);
   dailyLoss = 0.0;
   maxEquity = accountEquityAtStart;
   tradesToday = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup code if needed
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (ShouldAvoidTrading()) return;
   if (!CheckRiskLimits()) return;

   // Example trend-based strategy
   double ma = iMA(NULL, 0, MovingAveragePeriod, 0, MODE_SMA, PRICE_CLOSE);
   double price = iClose(NULL, 0, 0);
   bool trendUp = price > ma;

   if (UseTrendFilter && !trendUp) return;

   int atr = iATR(NULL, 0, 14);
   double stopLossPoints = ATRMultiplier * atr;
   double takeProfitPoints = ATRMultiplier * atr;

   if (OpenTrade(trendUp, stopLossPoints, takeProfitPoints))
   {
      tradesToday++;
   }
}

//+------------------------------------------------------------------+
//| Check if trading should be avoided during news times             |
//+------------------------------------------------------------------+
bool ShouldAvoidTrading()
{
   return false;
}

//+------------------------------------------------------------------+
//| Check risk limits                                                |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dailyLoss = accountEquityAtStart - currentEquity;
   if (dailyLoss / accountEquityAtStart * 100 > MaxDailyLoss)
      return false;

   if ((accountEquityAtStart - currentEquity) / accountEquityAtStart * 100 > MaxDrawdown)
      return false;

   if (tradesToday >= MaxTradesPerDay)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Open a trade                                                     |
//+------------------------------------------------------------------+
bool OpenTrade(bool isBuy, double stopLossPoints, double takeProfitPoints)
{
   bool isOrderPlaced = false;
   string currentSymbol = Symbol();
   double lotSize = RiskPercent > 0 ? CalculateLotSize(stopLossPoints) : LotSize;
   double askPrice = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);          // Fetch the Ask price
   double bidPrice = SymbolInfoDouble(currentSymbol, SYMBOL_BID);          // Fetch the Bid price
   //double spread = NormalizeDouble(askPrice - bidPrice, Digits());         // Calculate the spread
   if(isBuy)
   {
      double stopLossPrice = bidPrice - stopLossPoints;
      double takeProfitPrice = bidPrice + takeProfitPoints;
      isOrderPlaced = trade.Buy(lotSize, currentSymbol, 0, stopLossPrice, takeProfitPrice, "Buy Trade");
   }
   else 
   {
      double stopLossPrice = askPrice + stopLossPoints;
      double takeProfitPrice = askPrice - takeProfitPoints;
      isOrderPlaced = trade.Sell(lotSize, currentSymbol, 0, stopLossPrice, takeProfitPrice, "Sell Trade");
   }
   
   if (isOrderPlaced)
   {
      Print("Order placed Successfully");
      return true;
   }
   else
   {
      Print("Failed to place order: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLoss)
{
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);
   double lotSize = riskAmount / (stopLoss / tickSize * tickValue * contractSize);
   return NormalizeDouble(lotSize, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP));
}
