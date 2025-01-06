#include <Trade\Trade.mqh>
#include <Controls\Button.mqh>  // For button control

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double entryPrice = 0;
double stopLoss = 0;
double trailEntryPrice = 0;
int additionalTradesCount = 0;
bool initialTradePlaced = false;
bool startTrading = false;          // Flag to start trading
string currentSymbol;
CTrade trade;                       // Declare the trade object for managing orders
CButton startButton;                // Create a button object


//+------------------------------------------------------------------+
//| Constants for SL movement (in ticks)                             |
//+------------------------------------------------------------------+
const double TRADE_DISTANCE = 1;    // 1 tick away from SL to trigger additional trade
const double STOPLOSS_DISTANCE = 2; // 2 ticks away from SL to stop adding trades

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
input int StopLossCandleIndex = 1;              // 1: Immediate previous candle, 2: Two candles back
input StopLossType StopLossOption = HighPrice;  // Stop-loss calculation type (dropdown)
input double StopLossBufferPoint = 5;           // 5 points added to stop-loss for safety

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create button on chart to trigger auto-trading
    startButton.Create(0, "StartButton", 0, 20, 150, 190, 110); // x1,y2,x2,y1
    startButton.Text("Start Auto Trading");
    
    // Create button on chart to trigger close all positions
    startButton.Create(0, "CloseAllPositions", 0, 210, 150, 370, 110); // x1,y2,x2,y1
    startButton.Text("Close All Positions");

    // Display settings on the chart
    DisplaySettings();

    return(INIT_SUCCEEDED);
}

// OnChartEvent handler to catch button clicks
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Check if the event is a button click event
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        // Check if the clicked object is our start button
        if (sparam == "StartButton")
        {
            startTrading = true;  // Set the flag to start trading
            Print("User Initiated the Automated Trading...");
        }
        else if (sparam == "CloseAllPositions")
        {
            CloseAllPositions(); // Close all positions for the current symbol
        }
    }
}

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
    // Required for the EA to function. Add any periodic logic here if needed.
    // Only execute trading logic if the user has pressed the start button
    if (startTrading)
    {
        Print("Auto Trading Started");
        // Check if there is an open position for the current symbol
        if (PositionsTotal() == 0)
        {
            // If no positions are open, place the initial trade
            currentSymbol = Symbol();
            PlaceInitialTrade();
        }
        else
        {
            // If an initial trade was placed, monitor the price and place additional trades
            if (initialTradePlaced)
            {
                MonitorPriceAndPlaceTrades();
            }
        }
    }
}

// Function to place the initial trade
void PlaceInitialTrade()
{
    // Example: Place a Sell trade (You can modify it to Buy based on your strategy)
    double price = SymbolInfoDouble(currentSymbol, SYMBOL_BID); // Get current bid price
    stopLoss = price + StopLossBufferPoint; // Set stop-loss to price + buffer points for safety
    double tp = 0; // No target exit, as per your strategy

    entryPrice = price;
    trailEntryPrice = price;

    // Place the initial sell order
    if (trade.Sell(0.01, currentSymbol, price, stopLoss, tp, "Initial Sell Trade") == false)
    {
        Print("Error opening initial sell order: ", GetLastError());
    }
    else
    {
        initialTradePlaced = true;
    }
}

// Function to monitor price and place additional trades
void MonitorPriceAndPlaceTrades()
{
    // Get the current price
    double currentPrice = SymbolInfoDouble(currentSymbol, SYMBOL_BID);  // Get current bid price

    Print("MonitorPriceAndPlaceTrades() -> TRADE_DISTANCE: ", TRADE_DISTANCE);
    Print("MonitorPriceAndPlaceTrades() -> stopLoss: ", stopLoss);
    Print("MonitorPriceAndPlaceTrades() -> stopLoss - TRADE_DISTANCE: ", stopLoss - TRADE_DISTANCE);
    // Check if the price is within 1 tick (TRADE_DISTANCE) of the stop-loss
    if (currentPrice > trailEntryPrice && startTrading)
    {
        if (currentPrice < stopLoss - STOPLOSS_DISTANCE && additionalTradesCount < 10) // Limit to 10 trades for safety
        {
            // Place additional sell trade
            double price = SymbolInfoDouble(currentSymbol, SYMBOL_BID); // Place at current market price

            // Place additional sell trade
            if (trade.Sell(0.01, currentSymbol, price, stopLoss, 0, "Additional Sell Trade") == false)
            {
                Print("Error opening additional sell order: ", GetLastError());
            }
            else
            {
                additionalTradesCount++;
                Print("Placed additional sell trade #", additionalTradesCount);
            }
        }

        // Stop placing additional trades once the price is 2 ticks away from the final stop-loss (STOPLOSS_DISTANCE)
        if (currentPrice = stopLoss - STOPLOSS_DISTANCE)
        {
            Print("Stop placing additional trades, final stop-loss reached.");
        }

        // Check if the stop-loss is hit for any trade
        if (currentPrice >= stopLoss)
        {
            CloseAllPositions(); // Close all positions if stop-loss is hit
        }
    }
}

// Function to close all positions
void CloseAllPositions()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionSelect(currentSymbol))  // Ensure the position is selected
        {
            // Close the position
            double price = SymbolInfoDouble(currentSymbol, SYMBOL_BID); // Close at current market price for sell
            if (trade.PositionClose(currentSymbol) == false)
            {
                Print("Error closing position: ", GetLastError());
            }
            else
            {
                Print("Position closed successfully.");
            }
        }
    }
    
    startTrading = false;        // Reset Flag
    initialTradePlaced = false;  // Reset flag
    additionalTradesCount = 0;   // Reset additional trades count
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

    // Create a label for each setting on the chart
    ObjectCreate(0, "StopLossCandleLabel", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "StopLossCandleLabel", OBJPROP_CORNER, 0);
    ObjectSetInteger(0, "StopLossCandleLabel", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "StopLossCandleLabel", OBJPROP_YDISTANCE, 170);
    ObjectSetString(0, "StopLossCandleLabel", OBJPROP_TEXT, stopLossCandleInfo);
    ObjectSetInteger(0, "StopLossCandleLabel", OBJPROP_COLOR, clrDarkRed);
    ObjectSetInteger(0, "StopLossCandleLabel", OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, "StopLossCandleLabel", OBJPROP_FONT, "Arial");
    
    ObjectCreate(0, "StopLossOptionLabel", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "StopLossOptionLabel", OBJPROP_CORNER, 0);
    ObjectSetInteger(0, "StopLossOptionLabel", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "StopLossOptionLabel", OBJPROP_YDISTANCE, 190); // Position below the previous label
    ObjectSetString(0, "StopLossOptionLabel", OBJPROP_TEXT, stopLossOptionInfo);
    ObjectSetInteger(0, "StopLossOptionLabel", OBJPROP_COLOR, clrDarkRed);
    ObjectSetInteger(0, "StopLossOptionLabel", OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, "StopLossOptionLabel", OBJPROP_FONT, "Arial");
}

