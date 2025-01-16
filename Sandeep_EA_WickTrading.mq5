
#include <Trade\Trade.mqh>


CTrade trade;             // Declare the trade object for managing orders
double baseLotSize = 0.01;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialization of variables and indicators
    Print("EA initialized.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("EA deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Placeholder for main EA logic executed every tick
    ExecuteStrategy();
}

//+------------------------------------------------------------------+
//| Function to determine trend based on selected timeframe         |
//+------------------------------------------------------------------+
bool DetermineTrend(string symbol, ENUM_TIMEFRAMES timeframe)
{
    // Example: Using Moving Averages to determine trend direction
    double maFast = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
    double maSlow = iMA(symbol, timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);

    if (maFast > maSlow)
        return true; // Uptrend
    else
        return false; // Downtrend
}

//+------------------------------------------------------------------+
//| Function to calculate stop-loss and take-profit                 |
//+------------------------------------------------------------------+
void CalculateStops(double openPrice, double wickSize, double &stopLoss, double &takeProfit)
{
    stopLoss = openPrice - wickSize - 3 * _Point;
    takeProfit = openPrice + (openPrice - stopLoss); // Example target
}

//+------------------------------------------------------------------+
//| Function to monitor candle formation                            |
//+------------------------------------------------------------------+
bool MonitorCandle(string symbol, ENUM_TIMEFRAMES timeframe, bool trendUp, double &entryPrice, double &stopLoss, double &takeProfit)
{
    double openPrice = iOpen(symbol, timeframe, 1);
    double highPrice = iHigh(symbol, timeframe, 1);
    double lowPrice = iLow(symbol, timeframe, 1);
    double closePrice = iClose(symbol, timeframe, 1);

    double wickSize = trendUp ? openPrice - lowPrice : highPrice - openPrice;

    if ((trendUp && closePrice > openPrice) || (!trendUp && closePrice < openPrice))
    {
        entryPrice = openPrice;
        CalculateStops(openPrice, wickSize, stopLoss, takeProfit);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Function to place a trade                                        |
//+------------------------------------------------------------------+
void PlaceTrade(string symbol, double entryPrice, double stopLoss, double takeProfit, bool trendUp)
{
    bool orderPlaced;
    if (trendUp)
    {
    
        orderPlaced = trade.BuyLimit(baseLotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_DAY, 0, "Buy Limit Trade");
    }
    else
    {
        orderPlaced = trade.SellLimit(baseLotSize, entryPrice, symbol, stopLoss, takeProfit, ORDER_TIME_DAY, 0, "Sell Limit Trade");
    }

    if (orderPlaced)
    {
        Print("Order placed successfully: ");
    }
    else
    {
        Print("Error placing order: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Main EA logic                                                   |
//+------------------------------------------------------------------+
void ExecuteStrategy()
{
    string symbol = _Symbol;
    ENUM_TIMEFRAMES timeframe = PERIOD_M5;
    bool trendUp = DetermineTrend(symbol, timeframe);

    double entryPrice, stopLoss, takeProfit;
    if (MonitorCandle(symbol, timeframe, trendUp, entryPrice, stopLoss, takeProfit))
    {
        PlaceTrade(symbol, entryPrice, stopLoss, takeProfit, trendUp);
    }
}

