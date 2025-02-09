#include <Trade\Trade.mqh>
#include <Controls\Button.mqh>  // For button control
#include <Controls\Label.mqh>   // For Label control
#include <Controls\Edit.mqh>

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
double stopLoss = 0;
double takeProfit = 0;
double startTradePrice = 0;
double stopTradePrice = 0;
double trailEntryPrice = 0;
double baseLotSize = 0.01;
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
CLabel baseLotsLabel;               // Declare a label object
CButton decreaseBaseLotSizeButton;  // Create a button object
CEdit baseLotSizeInput;             // Text input for lot size
CButton increaseBaseLotSizeButton;  // Create a button object


//+------------------------------------------------------------------+
//| Constants for SL movement (in ticks)                             |
//+------------------------------------------------------------------+
const double TRADE_STOP_DISTANCE = 2; // 2 ticks away from SL to stop adding trades
const double TRADE_START_DISTANCE = 12; // 2 ticks away from SL to stop adding trades

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
  
  
    // Create a label on the chart
    baseLotsLabel.Create(0, "BaseLotSizeLabel", 0, 20, 260, 100, 230);     // x1, y2, x2, y1
    baseLotsLabel.Text("Base Lot:");                                       // Set the label text
    baseLotsLabel.Color(clrBlack);                                        // Set the label text color
    baseLotsLabel.FontSize(10);                                           // Set the font size
    baseLotsLabel.Font("Arial"); 

    // Create button on chart
    decreaseBaseLotSizeButton.Create(0, "DecreaseBaseLotSizeButton", 0, 110, 290, 160, 260); // x1, y2, x2, y1
    decreaseBaseLotSizeButton.Text("▼");
    decreaseBaseLotSizeButton.ColorBackground(clrLightSalmon);

    // Create text input on chart
    baseLotSizeInput.Create(0, "LotSizeInput", 0, 170, 290, 280, 260); // x1, y2, x2, y1
    baseLotSizeInput.Text("0.01");
    baseLotSizeInput.TextAlign(ALIGN_CENTER);
    baseLotSizeInput.Deactivate();
    
    // Create button on chart
    increaseBaseLotSizeButton.Create(0, "IncreaseBaseLotSizeButton", 0, 290, 290, 340, 260); // x1, y2, x2, y1
    increaseBaseLotSizeButton.Text("▲");
    increaseBaseLotSizeButton.ColorBackground(clrLightGreen);
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
            buyTrade = true;
            currentSymbol = Symbol();
            SetStopLossTakeProfitEntryPrice();
            Print("User Initiated the Buy Trade");
            startTrading = true;  // Set the flag to start trading
        }
        else if (sparam == "SellButton")
        {
            buyTrade = false;
            currentSymbol = Symbol();
            SetStopLossTakeProfitEntryPrice();
            Print("User Initiated the Sell Trade");
            startTrading = true;  // Set the flag to start trading
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
            OnHighButtonClicked();
        }
        else if (sparam == "LowButton")
        {
            OnLowButtonClicked();
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
        else if (sparam == "DecreaseBaseLotSizeButton")
        {
            if (baseLotSize > 0.01)
            {
               baseLotSize = NormalizeDouble(baseLotSize - 0.01, 2);
               baseLotSizeInput.Text(DoubleToString(baseLotSize, 2));
               Print("Base lot size decreased to: ", baseLotSize);
            }
        }
        else if (sparam == "IncreaseBaseLotSizeButton")
        {
            if (baseLotSize >= 0.01 && baseLotSize < 10.00)
            {
               baseLotSize = NormalizeDouble(baseLotSize + 0.01, 2);
               baseLotSizeInput.Text(DoubleToString(baseLotSize, 2));
               Print("Base lot size increased to: ", baseLotSize);
            }
        }
    }
}

void OnHighButtonClicked()
{
   stopLossOHLCOption = HighPrice;
   openButton.ColorBackground(clrRed);
   highButton.ColorBackground(clrGreen);
   lowButton.ColorBackground(clrRed);
   closeButton.ColorBackground(clrRed);
   Print("SL OHLC option set to -> ", stopLossOHLCOption);
}

void OnLowButtonClicked()
{
   stopLossOHLCOption = LowPrice;
   openButton.ColorBackground(clrRed);
   highButton.ColorBackground(clrRed);
   lowButton.ColorBackground(clrGreen);
   closeButton.ColorBackground(clrRed);
   Print("SL OHLC option set to -> ", stopLossOHLCOption);
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
         if (buyTrade) {
            double price = NormalizeDouble(SymbolInfoDouble(currentSymbol, SYMBOL_ASK), Digits()); // Get current ASK price
            Print("Ask Price: ", price, " and startTradePrice: ", startTradePrice, " and stopTradePrice: ", stopTradePrice);
            if (price <= startTradePrice && price > stopTradePrice)
            {
                 PlaceBuyTrade(price);
            }
         }
         else 
         {
            double price = NormalizeDouble(SymbolInfoDouble(currentSymbol, SYMBOL_BID), Digits()); // Get current BID price
            Print("Bid Price: ", price, " and startTradePrice: ", startTradePrice, " and stopTradePrice: ", stopTradePrice);
            if (price >= startTradePrice && price < stopTradePrice)
            {
               PlaceSellTrade(price);
            }
         }
         
         if (buyTrade)
         {
              double price = NormalizeDouble(SymbolInfoDouble(currentSymbol, SYMBOL_ASK), Digits()); // Get current ASK price
              // Stop placing additional trades once the price is 2 ticks away from the final stop-loss (TRADE_STOP_DISTANCE)
              if (price == stopTradePrice)
              {
                  Print("Stop placing additional sell trades, final TRADE-STOP price reached.");
              }
              // Check if the stop-loss is hit for any trade
              if (price <= stopLoss)
              {
                  Print("Stop loss activated, Closing all the positions.......");
                  CloseAllPositions(); // Close all positions if stop-loss is hit
              }
         }
         else 
         {    
              double price = NormalizeDouble(SymbolInfoDouble(currentSymbol, SYMBOL_BID), Digits()); // Get current BID price
              // Stop placing additional trades once the price is 2 ticks away from the final stop-loss (TRADE_STOP_DISTANCE)
              if (price == stopTradePrice)
              {
                  Print("Stop placing additional sell trades, final TRADE-STOP price reached.");
              }
              // Check if the stop-loss is hit for any trade
              if (price >= stopLoss)
              {
                  Print("Stop loss activated, Closing all the positions.......");
                  CloseAllPositions(); // Close all positions if stop-loss is hit
              }
         }
    }
    
    // Testing the Prices
    // Print("1. LTP: ", SYMBOL_LAST, " , BID: ", SYMBOL_BID, " , ASK: ", SYMBOL_ASK);
    // Print("2. LTP: ", SymbolInfoDouble(currentSymbol, SYMBOL_LAST), " , BID: ", SymbolInfoDouble(currentSymbol, SYMBOL_BID), " , ASK: ", SymbolInfoDouble(currentSymbol, SYMBOL_ASK));
    
}

void SetStopLossTakeProfitEntryPrice()
{
   if (buyTrade)
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
       else
       {
           // default set to low price of selected SL candle.
           OnLowButtonClicked();
           stopLoss = NormalizeDouble(selectedCandleLow - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
       }
       startTradePrice = NormalizeDouble(stopLoss + (TRADE_START_DISTANCE * Point()), Digits());
       stopTradePrice = NormalizeDouble(stopLoss + (TRADE_STOP_DISTANCE * Point()), Digits());
       takeProfit = 0;
       Print("selectedCandleLow: ", selectedCandleLow, " and selectedCandleClose: ", selectedCandleClose, " and startTradePrice: ", startTradePrice, " and stopLoss: ", stopLoss);
   }
   else
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
       else
       {
           // default set to high price of selected SL candle.
           OnHighButtonClicked();
           stopLoss = NormalizeDouble(selectedCandleHigh - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
       }
       startTradePrice = NormalizeDouble(stopLoss - (TRADE_START_DISTANCE * Point()), Digits());
       stopTradePrice = NormalizeDouble(stopLoss - (TRADE_STOP_DISTANCE * Point()), Digits());
       takeProfit = 0;
       Print("selectedCandleOpen: ", selectedCandleOpen, " and selectedCandleHigh: ", selectedCandleHigh, " and startTradePrice: ", startTradePrice, " and stopLoss: ", stopLoss);
   }
}

// Function to place the buy trade
void PlaceBuyTrade(double price)
{
    // Place the buy order
    if (trade.Buy(baseLotSize, currentSymbol, price, stopLoss, takeProfit, "Buy Trade") == false)
    {
        Print("Error opening initial buy order: ", GetLastError());
    }
    else
    {
        startTradePrice = NormalizeDouble(price - (1 * Point()), Digits());
        //trailEntryPrice = price;
        //initialTradePlaced = true;
        Print("Placed Buy Trade with: EntryPrice: ",price, " and StopLoss: ", stopLoss);
    }
}

// Function to place the sell trade
void PlaceSellTrade(double price)
{
    // Place the sell order
    if (trade.Sell(baseLotSize, currentSymbol, price, stopLoss, takeProfit, "Sell Trade") == false)
    {
        Print("Error opening initial sell order: ", GetLastError());
    }
    else
    {
        startTradePrice = NormalizeDouble(price + (1 * Point()), Digits());
        //entryPrice = price;
        //trailEntryPrice = price;
        //initialTradePlaced = true;
        Print("Placed Sell Trade with: EntryPrice: ",price, " and StopLoss: ", stopLoss);
    }
}

// Function to close all positions
void CloseAllPositions()
{
    int totalOpenPositions = PositionsTotal();
    Print("Total positions to be closed: ", totalOpenPositions);
    for (int i = 0; i < totalOpenPositions; i++)
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
    
    CloseAllPendingOrders();
    
    startTrading = false;        // Reset Flag
    additionalTradesCount = 0;   // Reset additional trades count
    stopLoss = 0;
}

void CloseAllPendingOrders()
{
    // Close all pending orders
    int totalOrders = OrdersTotal();
    Print("Total pending orders to be closed: ", totalOrders);
    for (int i = totalOrders - 1; i >= 0; i--)
    {
        Print("Selecting order no. : ", i);
        ulong orderTicket = OrderGetTicket(i);
        //ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);  // Get order type

        // Check if the order is a pending order
        //if (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
        //    orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
        if (!trade.OrderDelete(orderTicket))
        {
            Print("Error deleting pending order: ", GetLastError());
        }
        else
        {
            Print("Pending order ", i + 1, " deleted successfully.");
        }
    }
}