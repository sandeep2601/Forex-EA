#include <Trade\Trade.mqh>
#include <Controls\Button.mqh>  // For button control
#include <Controls\Label.mqh>   // For Label control
#include <Controls\Edit.mqh>
#include "HelperFunctions.mqh"  // HelperMethods file

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
int stopLossCandleIndex = 1;              // 1: Immediate previous candle, 2: Two candles back
bool initialTradePlaced = false;
bool startTrading = false;          // Flag to start trading
bool buyTrade = true;               // Flag to set which trade is placed buy or sell
bool isLotMultiplierEnable = false; // Flag to enable or disable lot multiplier
bool userClosedPositionsOrOrders = false;
string currentSymbol;
ulong sortedPositionTickets[];      // Global variable to store sorted position tickets
StopLossType stopLossOHLCOption = HighPrice;  // Stop-loss calculation type
CTrade trade;                       // Declare the trade object for managing orders
CButton startButton;                // Create a button object
CButton buyButton;                  // Create a button object
CButton sellButton;                 // Create a button object
CButton closePositionsButton;       // Create a button object
CButton closePendingOrdersButton;   // Create a button object
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
CLabel lotMultiplierLabel;          // Declare a label object
CButton lotMultiplierOnButton;      // Create a button object
CButton lotMultiplierOffButton;     // Create a button object
CButton modifySLButton;             // Create a button object
CLabel positionDetailLabel;         // Declare a label object
CEdit slModifyInput;                // Text input for lot size


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
    closePositionsButton.Create(0, "CloseAllPositions", 0, 160, 140, 240, 110); // x1, y2, x2, y1
    closePositionsButton.Text("Positions");
    closePositionsButton.ColorBackground(clrLightSlateGray);
    
    // Create button on chart to trigger close all positions
    closePendingOrdersButton.Create(0, "ClosePendingOrders", 0, 250, 140, 340, 110); // x1, y2, x2, y1
    closePendingOrdersButton.Text("Pen Orders");
    closePendingOrdersButton.ColorBackground(clrLightSlateGray);
    

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
  
  
    // Create a label on the chart
    lotMultiplierLabel.Create(0, "LotMultiplierLabel", 0, 20, 310, 100, 280);     // x1, y2, x2, y1
    lotMultiplierLabel.Text("Lot Multiply:");                                       // Set the label text
    lotMultiplierLabel.Color(clrBlack);                                        // Set the label text color
    lotMultiplierLabel.FontSize(10);                                           // Set the font size
    lotMultiplierLabel.Font("Arial"); 

    // Create button on chart
    lotMultiplierOnButton.Create(0, "LotMultiplierOnButton", 0, 110, 340, 160, 310); // x1, y2, x2, y1
    lotMultiplierOnButton.Text("ON");
    lotMultiplierOnButton.ColorBackground(clrRed);
    
    // Create button on chart
    lotMultiplierOffButton.Create(0, "LotMultiplierOffButton", 0, 170, 340, 220, 310); // x1, y2, x2, y1
    lotMultiplierOffButton.Text("OFF");
    lotMultiplierOffButton.ColorBackground(clrGreen);  
    
    // Create button on chart
    modifySLButton.Create(0, "ModifySLButton", 0, 230, 340, 340, 310); // x1, y2, x2, y1
    modifySLButton.Text("Modify SL");
    modifySLButton.ColorBackground(clrLightSlateGray);  
    
    
    // Create a label on the chart
    positionDetailLabel.Create(0, "PositionDetailLabel", 0, 20, 350, 340, 320); // x1, y2, x2, y1
    positionDetailLabel.Text("Avg. Price: 0, Lots: 0, SL: $0");                             // Set the label text
    positionDetailLabel.Color(clrBlack);                                        // Set the label text color
    positionDetailLabel.FontSize(12);                                           // Set the font size
    positionDetailLabel.Font("Arial");
    
      
    // Create the decimal text input field
    slModifyInput.Create(0, "SLModifyInput", 0, 20, 420, 120, 390);
    slModifyInput.Text("0.0000");    // Set default SL
     
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
            CloseSortedPositions(); // Close all open positions
        }
        else if (sparam == "ClosePendingOrders")
        {
            CloseAllPendingOrders(); // Close all pending orders
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
        else if (sparam == "LotMultiplierOnButton")
        {
            if (isLotMultiplierEnable == false)
            {
               isLotMultiplierEnable = true;
               lotMultiplierOffButton.ColorBackground(clrRed);
               lotMultiplierOnButton.ColorBackground(clrGreen);
               Print("Lot Multiply is : Enabled");
            }
        }
        else if (sparam == "LotMultiplierOffButton")
        {
            if (isLotMultiplierEnable == true)
            {
               isLotMultiplierEnable = false;
               lotMultiplierOffButton.ColorBackground(clrGreen);
               lotMultiplierOnButton.ColorBackground(clrRed);
               Print("Lot Multiply is : Disabled");
            }
        }
        else if (sparam == "PositionDetailButton")
        {
            SortPositions();
        }
        else if (sparam == "ModifySLButton")
        {
            ModifyStopLoss();
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
    //if (startTrading)
    //{         
    //}
    
    // Testing the Prices
    // Print("1. LTP: ", SYMBOL_LAST, " , BID: ", SYMBOL_BID, " , ASK: ", SYMBOL_ASK);
    // Print("2. LTP: ", SymbolInfoDouble(currentSymbol, SYMBOL_LAST), " , BID: ", SymbolInfoDouble(currentSymbol, SYMBOL_BID), " , ASK: ", SymbolInfoDouble(currentSymbol, SYMBOL_ASK));
    
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    
    if (trans.type == TRADE_TRANSACTION_DEAL_ADD) // Position added or deleted.
    {
        //Print("-------------------------------Start-----OnTradeTransaction-------------------------------");
        //Print("Transaction Type: ", TradeTransactionTypeToString(trans.type));
        //Print("Order Ticket: ", trans.order);
        //Print("Order Type: ", OrderTypeToString(trans.order_type));
        //Print("Order State: ", OrderStateToString(trans.order_state));
        //Print("Position Ticket: ", trans.position);
        //Print("Position By: ", trans.position_by);
        //Print("Price: ", trans.price);
        //Print("Price Trigger: ", trans.price_trigger);
        //Print("Price SL: ", trans.price_sl);
        //Print("Price TP: ", trans.price_tp);
        //Print("Deal: ", trans.deal);
        //Print("Deal Type: ", DealTypeToString(trans.deal_type));
        //Print("Volume: ", trans.volume);
        //Print("Symbol: ", trans.symbol);
        //Print("Time Expiration: ", trans.time_expiration);
        //Print("Time Type: ", TimeTypeToString(trans.time_type));
        //Print("-------------------------------End-------OnTradeTransaction-------------------------------");
        SortPositions();
    }
}



void SetStopLossTakeProfitEntryPrice()
{
    if (buyTrade)
    {
        // Get data from the selected candle (immediate previous or two candles back)
        double selectedCandleOpen = iOpen(NULL, Period(), stopLossCandleIndex);
        double selectedCandleHigh = iHigh(NULL, Period(), stopLossCandleIndex);
        double selectedCandleLow = iLow(NULL, Period(), stopLossCandleIndex);
        double selectedCandleClose = iClose(NULL, Period(), stopLossCandleIndex);
        
        // Determine stop-loss price based on user selection (high or open)
        if (stopLossOHLCOption == OpenPrice)
        {
            stopLoss = NormalizeDouble(selectedCandleOpen - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleOpen + (TRADE_START_DISTANCE * Point()), Digits());
        }
        else if (stopLossOHLCOption == HighPrice)
        {
            stopLoss = NormalizeDouble(selectedCandleHigh - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleHigh + (TRADE_START_DISTANCE * Point()), Digits());
        }
        if (stopLossOHLCOption == LowPrice)
        {
            stopLoss = NormalizeDouble(selectedCandleLow - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleLow + (TRADE_START_DISTANCE * Point()), Digits());
        }
        else if (stopLossOHLCOption == ClosePrice)
        {
            stopLoss = NormalizeDouble(selectedCandleClose - (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleClose + (TRADE_START_DISTANCE * Point()), Digits());
        }
       
        stopTradePrice = NormalizeDouble(stopLoss + (TRADE_STOP_DISTANCE * Point()), Digits());
        takeProfit = 0;
        Print("selectedCandleLow: ", selectedCandleLow, " and selectedCandleClose: ", selectedCandleClose);
        Print("startTradePrice: ", startTradePrice, " and stopTradePrice: ", stopTradePrice, " and stopLoss: ", stopLoss);
        
        double variableLotSize = baseLotSize;
        int noOfOrders = 1;
        double askPrice = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);          // Fetch the Ask price
        double bidPrice = SymbolInfoDouble(currentSymbol, SYMBOL_BID);          // Fetch the Bid price
        double spread = NormalizeDouble(askPrice - bidPrice, Digits());         // Calculate the spread
        Print("askPrice: ", askPrice, " and bidPrice: ", bidPrice, " and spread: ", spread);
        Print("BASE LOT BEFORE BUY TRADE: ", baseLotSize);
        for (; startTradePrice > stopTradePrice;)
        {
            Print("For loop => Entry Price: ", startTradePrice);
            PlaceBuyLimitTrade(NormalizeDouble(startTradePrice + spread, Digits()), stopLoss, variableLotSize);
            startTradePrice = NormalizeDouble(startTradePrice - Point(), Digits());
            
            // Update lot size if multiplier is enabled
            if (isLotMultiplierEnable)
            {
                noOfOrders++;
                if (noOfOrders == 7 || noOfOrders == 11)
                {
                    variableLotSize = NormalizeDouble(variableLotSize + 0.01, 2);
                }
            }
        }
        Print("startTradePrice: ", startTradePrice, " and stopTradePrice: ", stopTradePrice);
    }
    else
    { 
        // Get data from the selected candle (immediate previous or two candles back)
        double selectedCandleOpen = iOpen(NULL, Period(), stopLossCandleIndex);
        double selectedCandleHigh = iHigh(NULL, Period(), stopLossCandleIndex);
        double selectedCandleLow = iLow(NULL, Period(), stopLossCandleIndex);
        double selectedCandleClose = iClose(NULL, Period(), stopLossCandleIndex);
    
        // Determine stop-loss price based on user selection (high or open)
        if (stopLossOHLCOption == OpenPrice)
        {
            stopLoss = NormalizeDouble(selectedCandleOpen + (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price + buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleOpen - (TRADE_START_DISTANCE * Point()), Digits());
        }
        else if (stopLossOHLCOption == HighPrice)
        {
            stopLoss = NormalizeDouble(selectedCandleHigh + (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price + buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleHigh - (TRADE_START_DISTANCE * Point()), Digits());
        }
        else if (stopLossOHLCOption == LowPrice)
        {
            stopLoss = NormalizeDouble(selectedCandleLow + (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleLow - (TRADE_START_DISTANCE * Point()), Digits());
        }
        else if (stopLossOHLCOption == ClosePrice)
        {
            stopLoss = NormalizeDouble(selectedCandleClose + (StopLossBufferPoint * Point()), Digits());   // Set stop-loss to price - buffer points for safety
            startTradePrice = NormalizeDouble(selectedCandleClose - (TRADE_START_DISTANCE * Point()), Digits());
        }
        
        stopTradePrice = NormalizeDouble(stopLoss - (TRADE_STOP_DISTANCE * Point()), Digits());
        takeProfit = 0;
        Print("selectedCandleOpen: ", selectedCandleOpen, " and selectedCandleHigh: ", selectedCandleHigh);
        Print("startTradePrice: ", startTradePrice, " and stopTradePrice: ", stopTradePrice, " and stopLoss: ", stopLoss);
        
        double variableLotSize = baseLotSize;
        int noOfOrders = 1;
        double askPrice = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);          // Fetch the Ask price
        double bidPrice = SymbolInfoDouble(currentSymbol, SYMBOL_BID);          // Fetch the Bid price
        double spread = NormalizeDouble(askPrice - bidPrice, Digits());         // Calculate the spread
        Print("askPrice: ", askPrice, " and bidPrice: ", bidPrice, " and spread: ", spread);
        Print("BASE LOT BEFORE SELL TRADE: ", baseLotSize);
        for (; startTradePrice < stopTradePrice;)
        {
            Print("For loop => Entry Price: ", startTradePrice);
            PlaceSellLimitTrade(startTradePrice, NormalizeDouble(stopLoss + spread, Digits()), variableLotSize);
            startTradePrice = NormalizeDouble(startTradePrice + Point(), Digits());
            
            // Update lot size if multiplier is enabled
            if (isLotMultiplierEnable)
            {
                noOfOrders++;
                if (noOfOrders == 7 || noOfOrders == 11)
                {
                    variableLotSize = NormalizeDouble(variableLotSize + 0.01, 2);
                }
            }
        }
        Print("startTradePrice: ", startTradePrice, " and stopTradePrice: ", stopTradePrice);
    }
}

// Function to place the buy trade
void PlaceBuyLimitTrade(double limitPrice, double stopLossPrice, double lotSize)
{
    // Place the buy order
    if (trade.BuyLimit(lotSize, limitPrice, currentSymbol, stopLossPrice, takeProfit, ORDER_TIME_DAY, 0, "Buy Limit Trade") == false)
    {
        Print("Error opening buy limit order: ", GetLastError());  
    }
    else
    {
        Print("Placed Buy Limit Trade with => LotSize: ", lotSize, " EntryPrice: ",limitPrice, " and StopLoss: ", stopLossPrice);
    }
}

// Function to place the sell trade
void PlaceSellLimitTrade(double limitPrice, double stopLossPrice, double lotSize)
{
    // Place the sell order
    if (trade.SellLimit(lotSize, limitPrice, currentSymbol, stopLossPrice, takeProfit, ORDER_TIME_DAY, 0, "Sell Limit Trade") == false)
    {
        Print("Error opening sell limit order: ", GetLastError());
    }
    else
    {
        Print("Placed Sell Limit Trade with => LotSize: ", lotSize, " EntryPrice: ",limitPrice, " and StopLoss: ", stopLossPrice);
    }
}

// Function to close all positions based on the sorted list
void CloseSortedPositions()
{
    userClosedPositionsOrOrders = true;
    int totalSortedPositions = ArraySize(sortedPositionTickets);
    Print("Total Sorted open positions to be closed: ", totalSortedPositions);
    for (int i = 0; i < totalSortedPositions; i++)
    {
        ulong ticket = sortedPositionTickets[i];
        if (trade.PositionClose(ticket) == false)
        {
            Print("Error closing position with ticket: ", ticket, " and Error: ", GetLastError());
        }
        else
        {
            Print("Position with ticket: ", ticket, " closed successfully.");
        }
    }
    CloseAllPositions();
     
    // Clear the sorted list after closing positions
    ArrayResize(sortedPositionTickets, 0);
    userClosedPositionsOrOrders = false;
}

// Function to close all positions
void CloseAllPositions()
{
    int totalOpenPositions = PositionsTotal();
    Print("SAFE: Total positions to be closed: ", totalOpenPositions);
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
}

void CloseAllPendingOrders()
{
    // Close all pending orders
    userClosedPositionsOrOrders = true;
    int totalOrders = OrdersTotal();
    Print("Total pending orders to be closed: ", totalOrders);
    for (int i = totalOrders - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i);
        //ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);  // Get order type

        // Check if the order is a pending order
        //if (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
        //    orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
        if (!trade.OrderDelete(orderTicket))
        {
            Print("Error deleting pending order no: ", totalOrders - i, " Error: ", GetLastError());
        }
        else
        {
            Print("Pending order no: ", totalOrders - i, " deleted successfully.");
        }
    }
    userClosedPositionsOrOrders = false;
}

// Function to collect and sort positions by lot size
void SortPositions()
{
    int totalOpenPositions = PositionsTotal();
    int totalSLPositions = totalOpenPositions;
    ArrayResize(sortedPositionTickets, totalOpenPositions);
    
    if (totalOpenPositions > 0)
    {
        // Temporary array to store positions with their lot sizes
        struct PositionData
        {
            ulong ticket;
            double lotSize;
        };
   
        PositionData positions[];
        ArrayResize(positions, totalOpenPositions);
        double avgOpenPrice = 0;
        double totalLotSize = 0;
        double avgStopLossPrice = 0;
        double pointValue = Digits();
        for (int i = 0; i < totalOpenPositions; i++)
        {
            if (PositionGetTicket(i))
            {
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                double lotSize = PositionGetDouble(POSITION_VOLUME);
                double positionPriceOpen = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), pointValue);
                double positionSL = NormalizeDouble(PositionGetDouble(POSITION_SL), pointValue);
                Print("positionSL: ", positionSL);
                positions[i].ticket = ticket;
                positions[i].lotSize = lotSize;
                if ((int)positionSL == 0)
                {
                    totalSLPositions--;
                }
                else
                {
                    avgStopLossPrice = NormalizeDouble(avgStopLossPrice + positionSL, pointValue);
                    totalLotSize = NormalizeDouble(totalLotSize + lotSize, 2);
                    avgOpenPrice = NormalizeDouble(avgOpenPrice + positionPriceOpen, pointValue);
                }
            }
        }
        avgOpenPrice = NormalizeDouble(avgOpenPrice / totalSLPositions, pointValue);
        avgStopLossPrice = NormalizeDouble(avgStopLossPrice / totalSLPositions, pointValue);
        Print("AvgOpenPrice: ", avgOpenPrice, " AvgStopLossPrice: ", avgStopLossPrice);
    
        double totalSLInPrice = NormalizeDouble(MathAbs(avgOpenPrice - avgStopLossPrice), pointValue);
        int totalSlPoints = totalSLInPrice / 0.00001; // Divide by point to get the SL points.
        Print("totalSLInPrice: ", totalSLInPrice," totalSlPoints: ", totalSlPoints);
        Print("-----------------------------------------------------------------");
        
        double totalSLInDollars = NormalizeDouble(totalSlPoints * totalLotSize, 2);
        Print("TotalLotSize: ", totalLotSize, " =====>  totalSLInDollars: ", totalSLInDollars);
    
        string textData = "Avg. Price: " + NormalizeDouble(avgOpenPrice, pointValue) + ", Lots: " + totalLotSize + ", SL: $" + totalSLInDollars;
        positionDetailLabel.Text(textData);
        positionDetailLabel.Text(textData);
       
        // Sort the positions by lot size in descending order using manual sorting
        for (int i = 0; i < ArraySize(positions) - 1; i++)
        {
            for (int j = i + 1; j < ArraySize(positions); j++)
            {
                if (positions[i].lotSize < positions[j].lotSize) // Descending order
                {
                    PositionData temp = positions[i];
                    positions[i] = positions[j];
                    positions[j] = temp;
                }
            }
        }
   
        Print("Sorted positions are below: ");
        // Populate the sortedPositionTickets array
        for (int i = 0; i < ArraySize(positions); i++)
        {
            sortedPositionTickets[i] = positions[i].ticket;
            Print("Ticket: ", positions[i].ticket, " LotSize: ", positions[i].lotSize);
        }
   
        Print("Positions sorted by lot size in order to close positions lately.");
    }
    else
    {
       string textData = "Avg. Price: 0, Lots: 0, SL: $0";
       positionDetailLabel.Text(textData);
       positionDetailLabel.Text(textData);
    }
}


void ModifyStopLoss()
{
    double newStopLossPrice = StringToDouble(slModifyInput.Text());
    // Select the position by symbol
    
    int totalOpenPositions = PositionsTotal();
    if (totalOpenPositions > 0)
    {
    }
     for (int i = 0; i < totalOpenPositions; i++)
     {
         if (PositionGetTicket(i))
         {
           ulong positionTicket = PositionGetInteger(POSITION_TICKET); // Get the position ticket
           double currentStopLoss = NormalizeDouble(PositionGetDouble(POSITION_SL), Digits());    // Get current stop loss
           double takeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), Digits());         // Get current take profit
           string posSymbol = PositionGetString(POSITION_SYMBOL);
   
           // Create a request to modify SL/TP
           MqlTradeRequest request;
           MqlTradeResult result;
           ZeroMemory(request); // Clear the request structure
           ZeroMemory(result);  // Clear the result structure
   
           request.action = TRADE_ACTION_SLTP;              // Action to modify SL/TP
           request.symbol = posSymbol;                      // Symbol of the position
           request.sl = NormalizeDouble(newStopLossPrice, Digits()); // New stop loss
           request.tp = takeProfit;                         // Keep the current take profit
           request.position = positionTicket;               // Position ticket to modify
   
           // Send the trade request
           if (OrderSend(request, result))
           {
               Print("Stop loss modified for position ", positionTicket, " to ", newStopLossPrice);
           }
           else
           {
               Print("Failed to modify stop loss for position ", positionTicket, ". Error: ", GetLastError());
           }
       }
    }
}