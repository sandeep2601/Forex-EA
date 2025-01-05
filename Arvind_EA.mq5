#include <Trade\Trade.mqh>

// Declare the trade object
CTrade trade;

//+------------------------------------------------------------------+
//| Enumeration for Stop-Loss Calculation                           |
//+------------------------------------------------------------------+
enum StopLossType
{
    HighPrice,  // Use the high price of the selected candle
    OpenPrice   // Use the open price of the selected candle
};

//+------------------------------------------------------------------+
//| Expert parameters                                                |
//+------------------------------------------------------------------+
input int StopLossCandleIndex = 1;       // 1: Immediate previous candle, 2: Two candles back
input StopLossType StopLossOption = HighPrice; // Stop-loss calculation type (dropdown)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create buttons for user actions
    ObjectCreate(0, "StartButton", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "StartButton", OBJPROP_CORNER, 0);
    ObjectSetInteger(0, "StartButton", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "StartButton", OBJPROP_YDISTANCE, 10);
    ObjectSetString(0, "StartButton", OBJPROP_TEXT, "Start Trade");

    ObjectCreate(0, "CloseAllButton", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "CloseAllButton", OBJPROP_CORNER, 0);
    ObjectSetInteger(0, "CloseAllButton", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "CloseAllButton", OBJPROP_YDISTANCE, 50);
    ObjectSetString(0, "CloseAllButton", OBJPROP_TEXT, "Close All Positions");

    // Display settings on the chart
    DisplaySettings();

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
    // Required for the EA to function. Add any periodic logic here if needed.
}

//+------------------------------------------------------------------+
//| Chart events function                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Check for button clicks
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        if (sparam == "StartButton")
        {
            StartTrade(); // Start the trading strategy
        }
        else if (sparam == "CloseAllButton")
        {
            CloseAllPositions(); // Close all positions for the current symbol
        }
    }
}

//+------------------------------------------------------------------+
//| Function to display EA settings on the chart                    |
//+------------------------------------------------------------------+
void DisplaySettings()
{
    string settingsLabel = "EA_Settings";
    string stopLossCandleInfo = StringFormat("Stop-Loss Candle: %s", 
                              StopLossCandleIndex == 1 ? "Immediate Previous" : "Two Candles Back");
    string stopLossOptionInfo = StringFormat("Stop-Loss Type: %s", 
                              StopLossOption == HighPrice ? "High Price" : "Open Price");

    // Combine all settings into one text
    string settingsText = stopLossCandleInfo + "\n" + stopLossOptionInfo;

    // Create a label object to display the settings
    ObjectCreate(0, settingsLabel, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, settingsLabel, OBJPROP_CORNER, 0);
    ObjectSetInteger(0, settingsLabel, OBJPROP_XDISTANCE, 200);
    ObjectSetInteger(0, settingsLabel, OBJPROP_YDISTANCE, 10);
    ObjectSetString(0, settingsLabel, OBJPROP_TEXT, settingsText);
    ObjectSetInteger(0, settingsLabel, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, settingsLabel, OBJPROP_FONTSIZE, 12);
    ObjectSetString(0, settingsLabel, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Start Trade Logic                                                |
//+------------------------------------------------------------------+
void StartTrade()
{
    double stopLoss, entryPrice;
    double slBuffer = 5 * Point(); // 5-point buffer

    // Get data from the selected candle (immediate previous or two candles back)
    double selectedCandleOpen = iOpen(NULL, PERIOD_M1, StopLossCandleIndex);
    double selectedCandleHigh = iHigh(NULL, PERIOD_M1, StopLossCandleIndex);

    // Determine stop-loss price based on user selection (high or open)
    if (StopLossOption == HighPrice)
    {
        stopLoss = selectedCandleHigh + slBuffer;
    }
    else if (StopLossOption == OpenPrice)
    {
        stopLoss = selectedCandleOpen + slBuffer;
    }

    entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // Place initial sell trade
    trade.Sell(0.1, Symbol(), entryPrice, stopLoss, 0, "Initial Sell");
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    // Close all positions for the current symbol
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionSelect(Symbol()))
        {
            trade.PositionClose(Symbol());
        }
    }
}
