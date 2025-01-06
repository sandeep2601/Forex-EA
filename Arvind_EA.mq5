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
CButton closePositionsButton;       // Create a button object


//+------------------------------------------------------------------+
//| Constants for SL movement (in ticks)                             |
//+------------------------------------------------------------------+
const double TRADE_STOP_DISTANCE = 2; // 2 ticks away from SL to stop adding trades

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
    closePositionsButton.Create(0, "CloseAllPositions", 0, 210, 150, 370, 110); // x1,y2,x2,y1
    closePositionsButton.Text("Close All Positions");

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
        // Check if there is an open position for the current symbol
        if (PositionsTotal() == 0)
        {
            // If positions are closed and SL is hit, stop trading
            if (initialTradePlaced)
            {
                Print("Stop-loss hit. Closing all positions and resetting flags.");
                CloseAllPositions();         // Ensure all positions are closed
                return;                      // Exit tick processing to prevent new trades
            }
            
            Print("Auto Trading Started");
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
    
    // Get data from the selected candle (immediate previous or two candles back)
    double selectedCandleOpen = iOpen(NULL, PERIOD_M1, StopLossCandleIndex);
    double selectedCandleHigh = iHigh(NULL, PERIOD_M1, StopLossCandleIndex);
    Print("selectedCandleOpen: ", selectedCandleOpen, " and selectedCandleHigh: ", selectedCandleHigh);

    // Determine stop-loss price based on user selection (high or open)
    if (StopLossOption == HighPrice)
    {
        stopLoss = selectedCandleHigh + (StopLossBufferPoint * Point());   // Set stop-loss to price + buffer points for safety
    }
    else if (StopLossOption == OpenPrice)
    {
        stopLoss = selectedCandleOpen + (StopLossBufferPoint * Point());   // Set stop-loss to price + buffer points for safety
    }
    Print("StopLossBufferPoint: ", StopLossBufferPoint, " and stopLoss: ", stopLoss);

    
    double price = SymbolInfoDouble(currentSymbol, SYMBOL_LAST); // Get current bid price
    double tp = 0; // No target exit, as per your strategy

    // Place the initial sell order
    if (trade.Sell(0.01, currentSymbol, price, stopLoss, tp, "Initial Sell Trade") == false)
    {
        Print("Error opening initial sell order: ", GetLastError());
    }
    else
    {
        entryPrice = price;
        trailEntryPrice = price;
        initialTradePlaced = true;
        Print("Placed First Trade with: EntryPrice: ",entryPrice, " and StopLoss: ", stopLoss);
    }
}

// Function to monitor price and place additional trades
void MonitorPriceAndPlaceTrades()
{
    // Get the current price
    double currentPrice = SymbolInfoDouble(currentSymbol, SYMBOL_LAST);  // Get last traded price

    // Check if the price is within 1 tick (TRADE_DISTANCE) of the stop-loss
    if (currentPrice > trailEntryPrice && startTrading)
    {
        if (currentPrice < stopLoss - (TRADE_STOP_DISTANCE * Point()) && additionalTradesCount < 30) // Limit to 30 trades for safety
        {
            // Place additional sell trade
            // double price = SymbolInfoDouble(currentSymbol, SYMBOL_LAST); // Place at current market price

            // Place additional sell trade
            if (trade.Sell(0.01, currentSymbol, currentPrice, stopLoss, 0, "Additional Sell Trade") == false)
            {
                Print("Error opening additional sell order: ", GetLastError());
            }
            else
            {
                additionalTradesCount++;
                trailEntryPrice = currentPrice;
                Print("Placed Additional Trade NO: ", additionalTradesCount, " with: EntryPrice: ",entryPrice, " and StopLoss: ", stopLoss);
            }
        }

        // Stop placing additional trades once the price is 2 ticks away from the final stop-loss (TRADE_STOP_DISTANCE)
        if (currentPrice == stopLoss - (TRADE_STOP_DISTANCE * Point()))
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

