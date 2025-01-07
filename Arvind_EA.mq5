#include <Trade\Trade.mqh>
#include <Controls\Button.mqh>  // For button control
#include <Controls\Label.mqh>   // For Label control

//+------------------------------------------------------------------+
//| Enumeration for Stop-Loss Calculation                           |
//+------------------------------------------------------------------+
enum StopLossType
{
    OpenPrice,  // Use the open price of the selected SL candle
    HighPrice,  // Use the high price of the selected SL candle
    LowPrice,   // Use the low price of the selected SL candle
    ClosePrice  // Use the close price of the selected SL candle
};

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double entryPrice = 0;
double stopLoss = 0;
double trailEntryPrice = 0;
int additionalTradesCount = 0;
int stopLossCandleIndex = 1;              // 1: Immediate previous candle, 2: Two candles back
bool initialTradePlaced = false;
bool startTrading = false;          // Flag to start trading
bool buyTrade = true;               // Flag to set which trade is placed buy or sell
string currentSymbol;
StopLossType stopLossOHLCOption = HighPrice;  // Stop-loss calculation type
CTrade trade;                       // Declare the trade object for managing orders
CButton startButton;                // Create a button object
CButton buyButton;                  // Create a button object
CButton sellButton;                 // Create a button object
CButton closePositionsButton;       // Create a button object
CLabel slCandleLabel;               // Declare a label object
CButton immediatePreviousSLCandle;  // Create a button object
CButton farPreviousSLCandle;        // Create a button object
CLabel slFromOHLCLabel;             // Declare a label object
CButton openButton;                 // Create a button object
CButton highButton;                 // Create a button object
CButton lowButton;                  // Create a button object
CButton closeButton;                // Create a button object


//+------------------------------------------------------------------+
//| Constants for SL movement (in ticks)                             |
//+------------------------------------------------------------------+
const double TRADE_STOP_DISTANCE = 2; // 2 ticks away from SL to stop adding trades

//+------------------------------------------------------------------+
//| Expert parameters                                                |
//+------------------------------------------------------------------+
input double StopLossBufferPoint = 5;           // 5 points added to stop-loss for safety

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{    
    // Add UI elements on the chart
    HandleUIGraphics();

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Function to display EA settings on the chart                    |
//+------------------------------------------------------------------+
void HandleUIGraphics()
{    
    // Create button on chart to trigger buy trade
    buyButton.Create(0, "BuyButton", 0, 20, 140, 80, 110); // x1, y2, x2, y1
    buyButton.Text("Buy");
    buyButton.ColorBackground(clrLightGreen);
    
    // Create button on chart to trigger sell trade
    sellButton.Create(0, "SellButton", 0, 90, 140, 150, 110); // x1, y2, x2, y1
    sellButton.Text("Sell");
    sellButton.ColorBackground(clrLightSalmon);
    
    // Create button on chart to trigger close all positions
    closePositionsButton.Create(0, "CloseAllPositions", 0, 170, 140, 340, 110); // x1, y2, x2, y1
    closePositionsButton.Text("Close All Positions");
    closePositionsButton.ColorBackground(clrLightSlateGray);
    
    // Create a label on the chart
    slCandleLabel.Create(0, "SLCandleLabel", 0, 20, 160, 100, 130);       // x1, y2, x2, y1
    slCandleLabel.Text("SL Candle:");                                     // Set the label text
    slCandleLabel.Color(clrBlack);                                        // Set the label text color
    slCandleLabel.FontSize(10);                                           // Set the font size
    slCandleLabel.Font("Arial");                                          // Set the font type
    
    // Create button on chart
    immediatePreviousSLCandle.Create(0, "ImmediatePreviousSLCandle", 0, 110, 190, 220, 160); // x1, y2, x2, y1
    immediatePreviousSLCandle.Text("Imm. Prev");
    immediatePreviousSLCandle.ColorBackground(clrGreen);
    
    // Create button on chart
    farPreviousSLCandle.Create(0, "FarPreviousSLCandle", 0, 240, 190, 340, 160); // x1, y2, x2, y1
    farPreviousSLCandle.Text("Far Prev");
    farPreviousSLCandle.ColorBackground(clrRed);
  
  
    // Create a label on the chart
    slFromOHLCLabel.Create(0, "SLFromOHLCLabel", 0, 20, 210, 100, 180);   // x1, y2, x2, y1
    slFromOHLCLabel.Text("SL From:");                                       // Set the label text
    slFromOHLCLabel.Color(clrBlack);                                        // Set the label text color
    slFromOHLCLabel.FontSize(10);                                           // Set the font size
    slFromOHLCLabel.Font("Arial"); 

    // Create button on chart
    openButton.Create(0, "OpenButton", 0, 110, 240, 160, 210); // x1, y2, x2, y1
    openButton.Text("Open");
    openButton.ColorBackground(clrRed);
    
    // Create button on chart
    highButton.Create(0, "HighButton", 0, 170, 240, 220, 210); // x1, y2, x2, y1
    highButton.Text("High");
    highButton.ColorBackground(clrGreen);
    
    // Create button on chart
    lowButton.Create(0, "LowButton", 0, 230, 240, 280, 210); // x1, y2, x2, y1
    lowButton.Text("Low");
    lowButton.ColorBackground(clrRed);
    
    // Create button on chart
    closeButton.Create(0, "CloseButton", 0, 290, 240, 340, 210); // x1, y2, x2, y1
    closeButton.Text("Close");
    closeButton.ColorBackground(clrRed);
}

// OnChartEvent handler to catch button clicks
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Check if the event is a button click event
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        // Check if the clicked object is our start button
        if (sparam == "BuyButton")
        {
            startTrading = true;  // Set the flag to start trading
            buyTrade = true;
            Print("User Initiated the Buy Trade");
        }
        else if (sparam == "SellButton")
        {
            startTrading = true;  // Set the flag to start trading
            buyTrade = false;
            Print("User Initiated the Sell Trade");
        }
        else if (sparam == "CloseAllPositions")
        {
            CloseAllPositions(); // Close all positions for the current symbol
        }
        else if (sparam == "ImmediatePreviousSLCandle")
        {
            stopLossCandleIndex = 1;
            immediatePreviousSLCandle.ColorBackground(clrGreen);
            farPreviousSLCandle.ColorBackground(clrRed);
            Print("SL candle set to -> ", stopLossCandleIndex == 1 ? "Immediate Previous Candle" : "Far Previous Candle");
        }
        else if (sparam == "FarPreviousSLCandle")
        {
            stopLossCandleIndex = 2;
            immediatePreviousSLCandle.ColorBackground(clrRed);
            farPreviousSLCandle.ColorBackground(clrGreen);
            Print("SL candle set to -> ", stopLossCandleIndex == 1 ? "Immediate Previous Candle" : "Far Previous Candle");
        }
        else if (sparam == "OpenButton")
        {
            stopLossOHLCOption = OpenPrice;
            openButton.ColorBackground(clrGreen);
            highButton.ColorBackground(clrRed);
            lowButton.ColorBackground(clrRed);
            closeButton.ColorBackground(clrRed);
            Print("SL OHLC option set to -> ", stopLossOHLCOption);
        }
        else if (sparam == "HighButton")
        {
            stopLossOHLCOption = HighPrice;
            openButton.ColorBackground(clrRed);
            highButton.ColorBackground(clrGreen);
            lowButton.ColorBackground(clrRed);
            closeButton.ColorBackground(clrRed);
            Print("SL OHLC option set to -> ", stopLossOHLCOption);
        }
        else if (sparam == "LowButton")
        {
            stopLossOHLCOption = LowPrice;
            openButton.ColorBackground(clrRed);
            highButton.ColorBackground(clrRed);
            lowButton.ColorBackground(clrGreen);
            closeButton.ColorBackground(clrRed);
            Print("SL OHLC option set to -> ", stopLossOHLCOption);
        }
        else if (sparam == "CloseButton")
        {
            stopLossOHLCOption = ClosePrice;
            openButton.ColorBackground(clrRed);
            highButton.ColorBackground(clrRed);
            lowButton.ColorBackground(clrRed);
            closeButton.ColorBackground(clrGreen);
            Print("SL OHLC option set to -> ", stopLossOHLCOption);
        }
    }
}

//+------------------------------------------------------------------+
//| Tick function                                                    |
//+------------------------------------------------------------------+
// Required for the EA to function. Add any periodic logic here if needed.
void OnTick()
{
    // Only execute trading logic if the user has initiated the trade
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
            if (buyTrade) {
               PlaceBuyTrade();
            }
            else {
               PlaceSellTrade();
            }
        }
        else
        {
            // If an initial trade was placed, monitor the price and place additional trades
            if (initialTradePlaced)
            {
                MonitorPriceAndPlaceAdditionalTrades();
            }
        }
    }
    
    // Testing the Prices
    // Print("1. LTP: ", SYMBOL_LAST, " , BID: ", SYMBOL_BID, " , ASK: ", SYMBOL_ASK);
    // Print("2. LTP: ", SymbolInfoDouble(currentSymbol, SYMBOL_LAST), " , BID: ", SymbolInfoDouble(currentSymbol, SYMBOL_BID), " , ASK: ", SymbolInfoDouble(currentSymbol, SYMBOL_ASK));
    
}

// Function to place the buy trade
void PlaceBuyTrade()
{
    // Get data from the selected candle (immediate previous or two candles back)
    double selectedCandleLow = iLow(NULL, Period(), stopLossCandleIndex);
    double selectedCandleClose = iClose(NULL, Period(), stopLossCandleIndex);

    // Determine stop-loss price based on user selection (high or open)
    if (stopLossOHLCOption == LowPrice)
    {
        stopLoss = NormalizeDouble(selectedCandleLow - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
    }
    else if (stopLossOHLCOption == ClosePrice)
    {
        stopLoss = NormalizeDouble(selectedCandleClose - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
    }
    
    double price = SymbolInfoDouble(currentSymbol, SYMBOL_ASK); // Get current ASK price
    double tp = 0; // No target exit, as per your strategy
    Print("selectedCandleLow: ", selectedCandleLow, " and selectedCandleClose: ", selectedCandleClose, "entry price: ", price, " and stopLoss: ", stopLoss);

    // Place the initial sell order
    if (trade.Buy(0.01, currentSymbol, price, stopLoss, tp, "Initial Buy Trade") == false)
    {
        Print("Error opening initial buy order: ", GetLastError());
    }
    else
    {
        entryPrice = price;
        trailEntryPrice = price;
        initialTradePlaced = true;
        Print("Placed First Buy Trade with: EntryPrice: ",entryPrice, " and StopLoss: ", stopLoss);
    }
}

// Function to place the sell trade
void PlaceSellTrade()
{    
    // Get data from the selected candle (immediate previous or two candles back)
    double selectedCandleOpen = iOpen(NULL, Period(), stopLossCandleIndex);
    double selectedCandleHigh = iHigh(NULL, Period(), stopLossCandleIndex);

    // Determine stop-loss price based on user selection (high or open)
    if (stopLossOHLCOption == HighPrice)
    {
        stopLoss = NormalizeDouble(selectedCandleHigh + (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price + buffer points for safety

    }
    else if (stopLossOHLCOption == OpenPrice)
    {
        stopLoss = NormalizeDouble(selectedCandleOpen + (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price + buffer points for safety
    }
    
    double price = SymbolInfoDouble(currentSymbol, SYMBOL_BID); // Get current BID price
    double tp = 0; // No target exit, as per your strategy
    Print("selectedCandleOpen: ", selectedCandleOpen, " and selectedCandleHigh: ", selectedCandleHigh, "entry price: ", price, " and stopLoss: ", stopLoss);

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
        Print("Placed First Sell Trade with: EntryPrice: ",entryPrice, " and StopLoss: ", stopLoss);
    }
}

// Function to monitor price and place additional trades
void MonitorPriceAndPlaceAdditionalTrades()
{
    double price = 0;
    if (buyTrade)
    {
       // Get the current price
       price = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);  // Get BID/ASK price based on order type
   
       // Check if the price is within 1 tick (TRADE_DISTANCE) of the stop-loss
       if (price < trailEntryPrice && startTrading)
       {
           double tradeStopPrice = NormalizeDouble(stopLoss + (TRADE_STOP_DISTANCE * Point()), Digits());
           if (price > tradeStopPrice && additionalTradesCount < 30) // Limit to 30 trades for safety
           {
               // Place additional buy trade
               if (trade.Buy(0.01, currentSymbol, price, stopLoss, 0, "Additional Buy Trade") == false)
               {
                   Print("Error opening additional buy order: ", GetLastError());
               }
               else
               {
                   additionalTradesCount++;
                   trailEntryPrice = price;
                   Print("Placed Additional Buy Trade with count: ", additionalTradesCount, " with: EntryPrice: ",price, " and StopLoss: ", stopLoss);
               }
           }
   
           // Stop placing additional trades once the price is 2 ticks away from the final stop-loss (TRADE_STOP_DISTANCE)
           if (price == tradeStopPrice)
           {
               Print("Stop placing additional buy trades, final TRADE-STOP price reached.");
           }
   
           // Check if the stop-loss is hit for any trade
           if (price <= stopLoss)
           {
               CloseAllPositions(); // Close all positions if stop-loss is hit
           }
       }
    }
    else 
    {
       // Get the current price
       price = SymbolInfoDouble(currentSymbol, SYMBOL_BID);  // Get BID/ASK price based on order type
   
       // Check if the price is within 2 tick (TRADE_DISTANCE) of the stop-loss
       if (price > trailEntryPrice && startTrading)
       {
           double tradeStopPrice = NormalizeDouble(stopLoss - (TRADE_STOP_DISTANCE * Point()), Digits());
           if (price < tradeStopPrice && additionalTradesCount < 30) // Limit to 30 trades for safety
           {
               // Place additional sell trade
               if (trade.Sell(0.01, currentSymbol, price, stopLoss, 0, "Additional Sell Trade") == false)
               {
                   Print("Error opening additional sell order: ", GetLastError());
               }
               else
               {
                   additionalTradesCount++;
                   trailEntryPrice = price;
                   Print("Placed Additional Sell Trade with count: ", additionalTradesCount, " with: EntryPrice: ",price, " and StopLoss: ", stopLoss);
               }
           }
   
           // Stop placing additional trades once the price is 2 ticks away from the final stop-loss (TRADE_STOP_DISTANCE)
           if (price == tradeStopPrice)
           {
               Print("Stop placing additional sell trades, final TRADE-STOP price reached.");
           }
   
           // Check if the stop-loss is hit for any trade
           if (price >= stopLoss)
           {
               CloseAllPositions(); // Close all positions if stop-loss is hit
           }
       }
    }
}

// Function to close all positions
void CloseAllPositions()
{
    Print("Total positions to be closed: ", PositionsTotal());
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
                Print("Position ", i + 1 ," closed successfully.");
            }
        }
    }
    
    startTrading = false;        // Reset Flag
    initialTradePlaced = false;  // Reset flag
    additionalTradesCount = 0;   // Reset additional trades count
}
