//+------------------------------------------------------------------+
//|                                                 YuriEA1.0.mq5    |
//|                        Port of EngulfingArrows 1.4 Pine Script   |
//|                        Trades FINAL signals (plotBuy/plotSell)   |
//+------------------------------------------------------------------+
#property copyright "JHEYEHM property"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>

CTrade trade;
CPositionInfo positionInfo;

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// Trading Controls
input group "=== Trading Controls ==="
input ulong   MagicNumber = 24012026;
input int     Max_Open_Trades = 2;                 // Maximum number of open trades per symbol
input int     Wait_Between_Signals = 25;            // Number of bars to wait between new signals
input bool    InpOneSignalPerBar = true;

// Confirmation Entry Mode
input group "=== Confirmation Entry Mode ==="
input bool    UseConfirmationEntry = false;         // If true, wait for breakout confirmation instead of immediate entry
input int     ConfirmExpireBars = 3;                // How many bars after signal we allow the breakout entry
input double  ConfirmBuffer_ATR = 0.10;             // ATR buffer for confirmation (0.10 = 10% ATR)
input double  ConfirmBuffer_SpreadFactor = 1.2;     // Spread-based buffer multiplier for confirmation

// Lots & Splitting
input group "=== Position Size & Take Profit Splitting ==="
input double  Position_Size = 0.03;                 // Total lot size for each trade
input int     TP1_Percent = 50;                     // Percentage of position size for TP1
input int     TP2_Percent = 30;                     // Percentage of position size for TP2
input int     TP3_Percent = 20;                     // Percentage of position size for TP3

// SL/TP Model
input group "=== Stop Loss & Take Profit Settings ==="
input int     InpATRPeriod = 14;
input double  Stop_Loss_Multiplier = 1.5;          // Stop loss multiplier (based on ATR)
input double  Take_Profit_1_Multiplier = 1.0;      // Take profit 1 multiplier (risk-to-reward ratio)
input double  Take_Profit_2_Multiplier = 2.0;      // Take profit 2 multiplier (risk-to-reward ratio)
input double  InpR3 = 3.0;                         // legacy R3 (unused for TP3 runner)
input double  Take_Profit_3_Multiplier = 4.0;      // Take profit 3 multiplier (runner, risk-to-reward ratio)
input int     Minimum_Stop_Loss_Points = 0;         // Minimum stop loss in points (0 = use ATR only)

// SL Mode (NEW)
input group "=== Stop Loss Mode (NEW) ==="
enum ENUM_SL_MODE { SL_ATR = 0, SL_SWING = 1, SL_SWING_PLUS_ATR = 2 };
input ENUM_SL_MODE InpSLMode = SL_ATR;              // Stop loss calculation mode
input int    Swing_Lookback_Bars = 20;              // Lookback for swing high/low (bar 1..N)
input int    Swing_Use_Shift = 1;                   // Start from closed bar (1)
input double Swing_ATR_Padding_Mult = 0.30;         // Extra ATR padding when using swing modes
input double Swing_Spread_Padding_Factor = 1.0;    // Extra spread padding for swing SL

// Spread/Slippage Protection
input group "=== Spread & Slippage Protection ==="
input int     Maximum_Spread = 30;                  // Maximum allowed spread in points
input int     Maximum_Slippage = 20;                 // Maximum allowed slippage in points

// Breakeven + Lock Buffers
input group "=== Breakeven & Profit Lock Settings ==="
input double  Breakeven_Buffer_Multiplier = 1.2;   // Breakeven buffer multiplier (based on spread)
input int     Breakeven_Buffer_Points = 0;         // Additional breakeven buffer in points
input bool    Move_TP3_To_BE_After_TP1 = false;    // If true, TP3 SL moves to breakeven after TP1; if false, TP3 keeps original SL to allow runner pullbacks
input bool    Enable_TP3_Trailing = true;          // Enable ATR-based trailing stop for TP3 after TP2 closes
input double  TP3_Trail_ATR_Multiplier = 1.5;     // ATR multiplier for TP3 trailing stop distance
input double  Profit_Lock_Buffer_Multiplier = 0.5; // Profit lock buffer multiplier (based on spread)
input int     Profit_Lock_Buffer_Points = 0;        // Additional profit lock buffer in points

// Invalidation Logic
input group "=== Trade Invalidation Settings ==="
input bool    UseInvalidation = true;              // Enable trade invalidation
input int     Invalidation_Window_Bars = 8;         // Number of bars for invalidation window
input double  Invalidation_Buffer_Multiplier = 1.0; // Invalidation buffer multiplier (based on spread)
input int     Invalidation_Buffer_Points = 0;      // Additional invalidation buffer in points

// Gap Filter
input group "=== Gap Filter ==="
input bool    UseGapFilter = true;                 // Enable gap filter
input int     Gap_Filter_Threshold = 50;            // Maximum allowed gap in points

// Pine Script Parameters (matching Pine defaults)
input group "=== Pine Script Parameters ==="
input bool    InpShowConsecutiveArrows = true;
input bool    InpConfirmOnClose = true;
input bool    InpStrictBarCloseMode = true;  // true = only use closed bars (non-repainting), false = allow intrabar signals
input bool    InpUseQualityFilter = true;
input int     InpQualityEMALen = 200;
input bool    InpUseFlexibleEngulfing = true;
input double  InpEngulfingThreshold = 0.9;
input int     InpMinConsecutiveCandles = 2;
input string  InpFilterMode = "EMA + Structure";  // None, EMA Trend, Market Structure, RSI Momentum, EMA + RSI, EMA + Structure
input string  InpPresetMode = "Auto (Forex)";     // Auto (Forex), Manual
input int     InpEMALenManual = 50;
input int     InpRSILenManual = 14;
input double  InpRSIMid = 50.0;
input int     InpStructShortManual = 10;
input int     InpStructLongManual = 20;
input bool    InpEnableBlockers = false;
input bool    InpUseSpaceBlocker = true;
input bool    InpUseSlopeBlocker = true;
input bool    InpUseStructureBlocker = false;
input bool    InpUseImpulseBlocker = true;
input int     InpSpaceATRLen = 14;
input double  InpMinSpaceATR = 1.0;
input int     InpEMASlopeLen = 50;
input double  InpMinEmaSlopeATR = 0.05;
input int     InpStructLookback = 20;
input int     InpImpulseRangeLookback = 20;
input double  InpMaxEntryPctIntoImpulse = 0.70;

input bool    InpEnableContextBlockers = true;
input bool    InpUseEMASlopeBlockerContext = true;
input int     InpEMASlopeLenContext = 20;
input double  InpMinEMASlopeATR = 0.08;
input double  Context_EMA_SlopeMin_ATR = 0.02;  // formerly InpMinEMASlopeATR_Context
input bool    InpUseATRBodyBlocker = true;
input double  InpMinBodyATR = 0.35;
input bool    InpUseLateEntryBlocker = true;
input int     InpLateEntryLookback = 3;
input int     InpMaxSameColorBeforeEntry = 2;
input bool    InpUseProximityToEMA = true;
input double  InpEMAProxATR = 5.0;  // Increased default from 0.6 to 5.0 to prevent over-blocking
input bool    InpUseRecentBreakoutConfirm = false;
input int     InpBreakoutLookback = 10;
input double  InpBreakoutATR = 0.5;

input int     InpPivotLen = 5;
input int     InpZoneATRLen = 14;
input double  InpZoneATRMult = 1.0;
input int     InpZoneLookbackBars = 1200;
input int     InpMaxSupplyZones = 8;
input int     InpMaxDemandZones = 8;
input bool    InpAllowHotZones = true;
input bool    InpAllowStrongZones = true;
input bool    InpAllowNormalZones = false;
input string  InpZoneTouchMode = "Close";  // Close, Wick

// Candle Validation
input group "=== Candle Validation ==="
input bool    UseCandleValidation = true;         // Enable candle-based validation layer
input int     MaxWaitBars = 5;                    // Maximum bars to wait for confirmation

// Post-Signal Validator (NEW)
input group "=== Post-Signal Validator (NEW) ==="
input bool    UsePostSignalValidator = true;      // Enable post-signal validation layer
input int     PSV_MaxWaitBars = 6;               // Bars to wait after signal for confirmation
input int     PSV_SwingLookback = 20;            // Structure level detection
input int     PSV_AvgBodyPeriod = 14;            // For displacement calc
input double  PSV_StrongBodyRatio = 0.60;        // Body >= 60% of range
input double  PSV_CloseNearExtreme = 0.25;       // Close in top/bottom 25% of range
input double  PSV_DisplacementMult = 1.20;        // Body >= 1.2 * avgBody
input int     PSV_FreshLevelLookback = 80;       // Search back for origin candle
input double  PSV_FreshTouchATRFrac = 0.10;      // Tolerance for "touch" around level (ATR fraction)
input bool    PSV_RequireNoReclaim = true;       // Require next candle hold beyond level
input bool    PSV_EnableLogs = true;             // Enable PSV logging
input bool    PSV_RequireRetest = false;        // DEFAULT OFF: retest not required
input bool    PSV_EnterOnAcceptance = false;      // Optional: enter on acceptance (only if no-reclaim disabled)
input bool    PSV_IgnoreNewSignalsWhileWaiting = true; // Ignore new signals while PSV is waiting

// Logging
input group "=== Logging ==="
input bool    InpVerboseLogs = true;

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
datetime lastBarTime = 0;
int lastSignalBarIndex = -1;
int lastDetectedSignalBarIndex = -1000000;
int lastSignalDirection = 0;  // 1=buy, -1=sell, 0=none

// Candle validation state machine
enum ENUM_SIGNAL_STATE
{
   SIGNAL_IDLE = 0,
   SIGNAL_WAIT_BUY = 1,
   SIGNAL_WAIT_SELL = -1
};

ENUM_SIGNAL_STATE currentState = SIGNAL_IDLE;
datetime signalBarTime = 0;  // Time of signal bar (for tracking across bar updates)
int barsWaited = 0;

// Post-Signal Validator state machine
enum PSV_STATE { PSV_IDLE = 0, PSV_WAIT_BUY = 1, PSV_WAIT_SELL = 2 };
PSV_STATE psv_state = PSV_IDLE;
datetime psv_signal_bar_time = 0;
int psv_waited = 0;
double psv_accept_level = 0.0;
double psv_fresh_low = 0.0;
double psv_fresh_high = 0.0;
int psv_dir = 0;
bool psv_pending_hold_check = false;

// Pending confirmation entry tracking
struct PendingConfirmation
{
   bool active;              // Is there a pending confirmation?
   int direction;            // 1=buy, -1=sell
   datetime signalBarTime;   // Time of signal bar (bar 1)
   double signalHigh;        // High of signal bar
   double signalLow;         // Low of signal bar
   int barsLeft;             // Bars remaining until expiry
   int signalBarIndex;       // Bar index when signal occurred
};
PendingConfirmation pendingConfirm;

// Batch tracking structure (robust architecture)
struct BatchInfo
{
   int batchId;              // Unique batch identifier
   int direction;             // +1 buy, -1 sell
   datetime signalTime;       // When signal was generated
   double entryPrice;         // Entry price (Ask for buy, Bid for sell)
   double slInitial;          // Initial stop loss
   double tp1, tp2, tp3;      // Take profit levels
   double invalidateLevel;    // Price level that invalidates the signal
   datetime invalidateExpiry; // Time when invalidation window expires
   ulong ticket1, ticket2, ticket3;  // Position tickets (may change, use comment for reliability)
   bool movedToBE;            // Flag: TP1 closed, moved to breakeven
   bool movedToTP2;           // Flag: TP2 closed, TP3 is now a runner (SL remains at breakeven)
   bool invalidationTriggered; // Flag: invalidation condition met (was invalidationTriggered)
};

BatchInfo batches[];
int nextBatchId = 1;

// Zone tracking (simplified arrays)
double supplyTopPrices[];
double supplyBottomPrices[];
bool supplyIsStrong[];
int supplyBarIndex[];

double demandTopPrices[];
double demandBottomPrices[];
bool demandIsStrong[];
int demandBarIndex[];

int nearestSupplyIdx = -1;
int nearestDemandIdx = -1;

// Indicator handles
int atrHandle = INVALID_HANDLE;
int emaHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Maximum_Slippage);
   
   // Detect and set allowed filling mode (correct enum handling, not bitmask)
   int fill = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   switch(fill)
   {
      case SYMBOL_FILLING_FOK:
         trade.SetTypeFilling(ORDER_FILLING_FOK);
         if(InpVerboseLogs) Print("OnInit: Using ORDER_FILLING_FOK");
         break;
      case SYMBOL_FILLING_IOC:
         trade.SetTypeFilling(ORDER_FILLING_IOC);
         if(InpVerboseLogs) Print("OnInit: Using ORDER_FILLING_IOC");
         break;
      default:
         // Default/Return filling mode (no SYMBOL_FILLING_RETURN constant exists)
         trade.SetTypeFilling(ORDER_FILLING_RETURN);
         if(InpVerboseLogs) Print("OnInit: Using ORDER_FILLING_RETURN (default)");
         break;
   }
   
   trade.SetAsyncMode(false);
   
   // Initialize indicator handles
   atrHandle = iATR(_Symbol, _Period, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator handle");
      return INIT_FAILED;
   }
   
   // Initialize arrays
   ArrayResize(supplyTopPrices, 0);
   ArrayResize(supplyBottomPrices, 0);
   ArrayResize(supplyIsStrong, 0);
   ArrayResize(supplyBarIndex, 0);
   
   ArrayResize(demandTopPrices, 0);
   ArrayResize(demandBottomPrices, 0);
   ArrayResize(demandIsStrong, 0);
   ArrayResize(demandBarIndex, 0);
   
   ArrayResize(batches, 0);
   
   // Initialize pending confirmation
   pendingConfirm.active = false;
   pendingConfirm.direction = 0;
   pendingConfirm.barsLeft = 0;
   
   // Initialize Post-Signal Validator
   psv_state = PSV_IDLE;
   psv_signal_bar_time = 0;
   psv_waited = 0;
   psv_accept_level = 0.0;
   psv_fresh_low = 0.0;
   psv_fresh_high = 0.0;
   psv_dir = 0;
   psv_pending_hold_check = false;
   
   // Rebuild batches from open positions
   RebuildBatchesFromPositions();
   
   if(InpVerboseLogs)
      Print("YuriEA initialized successfully. Magic: ", MagicNumber);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   
   if(InpVerboseLogs)
      Print("YuriEA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
      
      // Update zones on new bar
      UpdateZones();
      
      // Check for new signals on closed bar (bar index 1)
      CheckForSignals();
      
      // Check Post-Signal Validator (on new bar only)
      if(UsePostSignalValidator)
         PSV_CheckValidation();
   }
   
   // Always run trade management (every tick)
   ManageTrades();
   CheckInvalidations();
   CleanupBatches();
   
   // Check candle validation (every tick)
   if(UseCandleValidation && !UsePostSignalValidator)
      CheckCandleValidation();
   
   // Check for confirmation entry triggers (every tick)
   if(UseConfirmationEntry && !UseCandleValidation && !UsePostSignalValidator)
      CheckConfirmationEntry(isNewBar);
}

//+------------------------------------------------------------------+
//| Helper: Get spread in points                                     |
//+------------------------------------------------------------------+
double GetSpreadPoints()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point > 0)
      return (ask - bid) / point;
   return 0;
}

//+------------------------------------------------------------------+
//| Helper: Normalize lot size                                        |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotStep <= 0)
      return lots;
   
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   return lots;
}

//+------------------------------------------------------------------+
//| Helper: Get ATR value                                            |
//+------------------------------------------------------------------+
double GetATRValue()
{
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return 0.0;
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get swing low                                             |
//+------------------------------------------------------------------+
double GetSwingLow(int lookback, int shift)
{
   int bars = Bars(_Symbol, _Period);
   if(bars < lookback + shift + 2) return iLow(_Symbol, _Period, 1);
   
   int idx = iLowest(_Symbol, _Period, MODE_LOW, lookback, shift);
   if(idx < 0) return iLow(_Symbol, _Period, 1);
   return iLow(_Symbol, _Period, idx);
}

//+------------------------------------------------------------------+
//| Helper: Get swing high                                            |
//+------------------------------------------------------------------+
double GetSwingHigh(int lookback, int shift)
{
   int bars = Bars(_Symbol, _Period);
   if(bars < lookback + shift + 2) return iHigh(_Symbol, _Period, 1);
   
   int idx = iHighest(_Symbol, _Period, MODE_HIGH, lookback, shift);
   if(idx < 0) return iHigh(_Symbol, _Period, 1);
   return iHigh(_Symbol, _Period, idx);
}

//+------------------------------------------------------------------+
//| Helper: Redistribute lots to ensure all legs meet minimum        |
//| Returns true if redistribution succeeded, false if fallback needed |
//+------------------------------------------------------------------+
bool RedistributeLots(double &lot1, double &lot2, double &lot3, double totalLots, 
                      int tp1Percent, int tp2Percent, int tp3Percent, bool &redistributed)
{
   redistributed = false;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(minLot <= 0 || lotStep <= 0)
      return true;  // Can't redistribute if min/step invalid
   
   // First, normalize each leg
   lot1 = NormalizeLot(totalLots * tp1Percent / 100.0);
   lot2 = NormalizeLot(totalLots * tp2Percent / 100.0);
   lot3 = NormalizeLot(totalLots * tp3Percent / 100.0);
   
   // Check if any leg is below minimum
   bool needsRedistribution = (lot1 < minLot && lot1 > 0) || 
                              (lot2 < minLot && lot2 > 0) || 
                              (lot3 < minLot && lot3 > 0);
   
   if(!needsRedistribution)
      return true;  // All legs are OK
   
   // Try redistribution: ensure all non-zero legs are at least minLot
   double totalNormalized = lot1 + lot2 + lot3;
   
   // If total is less than 3 * minLot, we can't do 3 legs
   if(totalNormalized < 3 * minLot)
   {
      // Fallback: use only TP3
      lot1 = 0;
      lot2 = 0;
      
      // Use all available lots, but ensure it meets minimum
      if(totalNormalized >= minLot)
         lot3 = NormalizeLot(totalLots);
      else
         lot3 = NormalizeLot(minLot);  // Use minimum even if it exceeds totalLots (fallback behavior)
      
      if(InpVerboseLogs)
         Print("LOT REDISTRIBUTION: Total too small for 3 legs (", totalNormalized, " < ", 3*minLot, 
               "). Fallback to 1-leg execution: TP3=", lot3, " (requested total: ", totalLots, ")");
      return false;  // Fallback used
   }
   
   // Redistribute: set all non-zero legs to at least minLot, then redistribute remainder proportionally
   int nonZeroCount = 0;
   if(lot1 > 0) nonZeroCount++;
   if(lot2 > 0) nonZeroCount++;
   if(lot3 > 0) nonZeroCount++;
   
   if(nonZeroCount == 0)
   {
      // All legs are zero - use TP3 only with minimum lot
      lot1 = 0;
      lot2 = 0;
      lot3 = NormalizeLot(minLot);
      if(InpVerboseLogs)
         Print("LOT REDISTRIBUTION: All legs zero. Fallback to 1-leg execution: TP3=", lot3, 
               " (requested total: ", totalLots, ")");
      return false;
   }
   
   // Reserve minimum for each non-zero leg
   double reserved = nonZeroCount * minLot;
   double remainder = totalNormalized - reserved;
   
   if(remainder < 0)
   {
      // Not enough for minimums - fallback to TP3 only
      lot1 = 0;
      lot2 = 0;
      
      // Use all available lots, but ensure it meets minimum
      if(totalNormalized >= minLot)
         lot3 = NormalizeLot(totalLots);
      else
         lot3 = NormalizeLot(minLot);  // Use minimum even if it exceeds totalLots (fallback behavior)
      
      if(InpVerboseLogs)
         Print("LOT REDISTRIBUTION: Not enough for minimums (total=", totalNormalized, ", need=", reserved, 
               "). Fallback to 1-leg execution: TP3=", lot3, " (requested total: ", totalLots, ")");
      return false;
   }
   
   // Set minimums
   if(lot1 > 0) lot1 = minLot;
   if(lot2 > 0) lot2 = minLot;
   if(lot3 > 0) lot3 = minLot;
   
   // Redistribute remainder proportionally
   int totalPercent = tp1Percent + tp2Percent + tp3Percent;
   if(totalPercent > 0)
   {
      if(lot1 > 0) lot1 += NormalizeLot(remainder * tp1Percent / totalPercent);
      if(lot2 > 0) lot2 += NormalizeLot(remainder * tp2Percent / totalPercent);
      if(lot3 > 0) lot3 += NormalizeLot(remainder * tp3Percent / totalPercent);
   }
   
   // Final normalization
   lot1 = NormalizeLot(lot1);
   lot2 = NormalizeLot(lot2);
   lot3 = NormalizeLot(lot3);
   
   redistributed = true;
   if(InpVerboseLogs)
      Print("LOT REDISTRIBUTION: Redistributed to meet minimums. TP1=", lot1, " TP2=", lot2, " TP3=", lot3);
   
   return true;
}

//+------------------------------------------------------------------+
//| Helper: Count positions by magic and symbol                      |
//+------------------------------------------------------------------+
int CountPositionsByMagicSymbol(ulong magic, string sym)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == magic && positionInfo.Symbol() == sym)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Helper: Find position ticket by exact comment match              |
//| Returns true if found, sets posTicket to the ticket             |
//+------------------------------------------------------------------+
bool FindPositionTicketByComment(ulong magic, string symbol, string comment, ulong &posTicket)
{
   posTicket = 0;
   // Match base format: "YURI#BatchID#TP1" (comment may include invalidation level suffix)
   string baseComment = comment;
   int pos = StringFind(comment, "#", 0);
   if(pos >= 0)
   {
      pos = StringFind(comment, "#", pos + 1);
      if(pos >= 0)
      {
         pos = StringFind(comment, "#", pos + 1);
         if(pos >= 0)
            baseComment = StringSubstr(comment, 0, pos);  // Remove invalidation level suffix
      }
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == magic && positionInfo.Symbol() == symbol)
         {
            string posComment = positionInfo.Comment();
            // Check if position comment starts with base comment (handles invalidation level suffix)
            if(StringFind(posComment, baseComment) == 0)
            {
               posTicket = positionInfo.Ticket();
               return true;
   }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Check if position exists by comment                      |
//+------------------------------------------------------------------+
bool HasPositionByComment(string comment)
{
   // Extract base comment (without invalidation level suffix)
   string baseComment = comment;
   int pos = StringFind(comment, "#", 0);
   if(pos >= 0)
   {
      pos = StringFind(comment, "#", pos + 1);
      if(pos >= 0)
      {
         pos = StringFind(comment, "#", pos + 1);
         if(pos >= 0)
            baseComment = StringSubstr(comment, 0, pos);  // Remove invalidation level suffix
      }
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == MagicNumber && positionInfo.Symbol() == _Symbol)
         {
            string posComment = positionInfo.Comment();
            // Check if position comment starts with base comment
            if(StringFind(posComment, baseComment) == 0)
               return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Find position ticket by comment (legacy wrapper)         |
//+------------------------------------------------------------------+
ulong FindPositionTicketByComment(string comment)
{
   ulong ticket = 0;
   FindPositionTicketByComment(MagicNumber, _Symbol, comment, ticket);
   return ticket;
}

//+------------------------------------------------------------------+
//| Helper: Close position by comment                                |
//+------------------------------------------------------------------+
bool ClosePositionByComment(ulong magic, string symbol, string comment)
{
   ulong ticket = 0;
   if(FindPositionTicketByComment(magic, symbol, comment, ticket))
   {
      if(positionInfo.SelectByTicket(ticket))
      {
         bool result = trade.PositionClose(ticket);
         if(!result && InpVerboseLogs)
            Print("ERROR: Failed to close position by comment. Ticket: ", ticket, " Error: ", GetLastError());
         return result;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helper: Close position by comment (legacy wrapper)              |
//+------------------------------------------------------------------+
bool ClosePositionByComment(string comment)
{
   return ClosePositionByComment(MagicNumber, _Symbol, comment);
}

//+------------------------------------------------------------------+
//| Helper: Encode invalidation level in comment                     |
//| Format: YURI#BatchID#TP1#InvPts where InvPts is points offset   |
//+------------------------------------------------------------------+
string EncodeCommentWithInvLevel(int batchId, string tp, double entryPrice, double invalidateLevel)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0)
      return "YURI#" + IntegerToString(batchId) + "#" + tp;
   
   // Store invalidation level as points offset from entry (compact integer)
   int invPts = (int)MathRound((invalidateLevel - entryPrice) / point);
   return "YURI#" + IntegerToString(batchId) + "#" + tp + "#" + IntegerToString(invPts);
}

//+------------------------------------------------------------------+
//| Helper: Decode invalidation level from comment                    |
//| Returns: invalidateLevel if found, 0 if not found                |
//+------------------------------------------------------------------+
double DecodeInvLevelFromComment(string comment, double entryPrice)
{
   int pos = StringFind(comment, "#", 0);
   if(pos < 0) return 0;
   
   // Find third # (after BatchID and TP)
   pos = StringFind(comment, "#", pos + 1);
   if(pos < 0) return 0;
   
   pos = StringFind(comment, "#", pos + 1);
   if(pos < 0) return 0;  // No invalidation level stored
   
   string invPtsStr = StringSubstr(comment, pos + 1);
   int invPts = (int)StringToInteger(invPtsStr);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) return 0;
   
   return entryPrice + invPts * point;
}

//+------------------------------------------------------------------+
//| Helper: Check spread OK                                          |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   double spreadPoints = GetSpreadPoints();
   return (spreadPoints <= Maximum_Spread);
}

//+------------------------------------------------------------------+
//| Helper: Check gap OK                                             |
//+------------------------------------------------------------------+
bool IsGapOK()
{
   if(!UseGapFilter)
      return true;
   
   double open0 = iOpen(_Symbol, _Period, 0);
   double close1 = iClose(_Symbol, _Period, 1);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point <= 0)
      return true;
   
   double gapPoints = MathAbs(open0 - close1) / point;
   return (gapPoints <= Gap_Filter_Threshold);
}

//+------------------------------------------------------------------+
//| Helper: Set trade context                                        |
//+------------------------------------------------------------------+
void SetTradeContext()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Maximum_Slippage);
}

//+------------------------------------------------------------------+
//| Update supply/demand zones                                       |
//+------------------------------------------------------------------+
//| Ports Pine script ta.pivothigh/ta.pivotlow logic                 |
//| Pine: ta.pivothigh(high, pivotLen, pivotLen) checks pivotLen bars |
//|       before and after the center bar                             |
//+------------------------------------------------------------------+
void UpdateZones()
{
   int bars = Bars(_Symbol, _Period);
   if(bars < InpPivotLen * 2 + 1)
      return;
   
   // Pine ta.pivothigh/ta.pivotlow: center bar must be highest/lowest
   // in range [center-pivotLen, center+pivotLen]
   // We check on bar InpPivotLen (which has pivotLen bars before and after)
   // Bar indexing: bar 0=current, bar 1=last closed, bar 2=previous, etc.
   // For pivot at bar N, we need N >= pivotLen to have enough history
   
   int centerBar = InpPivotLen;  // Bar with pivotLen bars before and after
   if(bars < centerBar + InpPivotLen + 1)
      return;
   
   // Detect pivot high (Pine: ta.pivothigh(high, pivotLen, pivotLen))
   double pivotHigh = 0;
   int pivotHighBar = -1;
   bool foundPivotHigh = false;
   
   double centerHigh = iHigh(_Symbol, _Period, centerBar);
   bool isPivotHigh = true;
   
   // Check all bars in range [center-pivotLen, center+pivotLen]
   for(int i = centerBar - InpPivotLen; i <= centerBar + InpPivotLen; i++)
   {
      if(i == centerBar)
         continue;  // Skip center bar itself
      
      double barHigh = iHigh(_Symbol, _Period, i);
      if(barHigh >= centerHigh)
      {
         isPivotHigh = false;
         break;
      }
   }
   
   if(isPivotHigh)
   {
      pivotHigh = centerHigh;
      pivotHighBar = bars - centerBar - 1;  // Convert to absolute bar index
      foundPivotHigh = true;
   }
   
   // Detect pivot low (Pine: ta.pivotlow(low, pivotLen, pivotLen))
   double pivotLow = 0;
   int pivotLowBar = -1;
   bool foundPivotLow = false;
   
   double centerLow = iLow(_Symbol, _Period, centerBar);
   bool isPivotLow = true;
   
   // Check all bars in range [center-pivotLen, center+pivotLen]
   for(int i = centerBar - InpPivotLen; i <= centerBar + InpPivotLen; i++)
   {
      if(i == centerBar)
         continue;  // Skip center bar itself
      
      double barLow = iLow(_Symbol, _Period, i);
      if(barLow <= centerLow)
      {
         isPivotLow = false;
         break;
      }
   }
   
   if(isPivotLow)
   {
      pivotLow = centerLow;
      pivotLowBar = bars - centerBar - 1;  // Convert to absolute bar index
      foundPivotLow = true;
   }
   
   // Get ATR for zone thickness
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return;
   double atr = atrBuffer[0];
   
   // Create supply zone
   if(foundPivotHigh && pivotHigh > 0)
   {
      // Check if zone already exists (avoid duplicates)
      bool zoneExists = false;
      for(int i = 0; i < ArraySize(supplyTopPrices); i++)
      {
         if(MathAbs(supplyTopPrices[i] - pivotHigh) < atr * 0.1)
         {
            zoneExists = true;
            break;
         }
      }
      
      if(!zoneExists)
      {
         int size = ArraySize(supplyTopPrices);
         ArrayResize(supplyTopPrices, size + 1);
         ArrayResize(supplyBottomPrices, size + 1);
         ArrayResize(supplyIsStrong, size + 1);
         ArrayResize(supplyBarIndex, size + 1);
         
         supplyTopPrices[size] = pivotHigh;
         supplyBottomPrices[size] = pivotHigh - atr * InpZoneATRMult;
         supplyIsStrong[size] = false;  // Simplified - would check range/volume in full version
         supplyBarIndex[size] = pivotHighBar;
         
         // Limit max zones
         if(ArraySize(supplyTopPrices) > InpMaxSupplyZones)
         {
            ArrayRemove(supplyTopPrices, 0, 1);
            ArrayRemove(supplyBottomPrices, 0, 1);
            ArrayRemove(supplyIsStrong, 0, 1);
            ArrayRemove(supplyBarIndex, 0, 1);
         }
      }
   }
   
   // Create demand zone
   if(foundPivotLow && pivotLow > 0)
   {
      bool zoneExists = false;
      for(int i = 0; i < ArraySize(demandBottomPrices); i++)
      {
         if(MathAbs(demandBottomPrices[i] - pivotLow) < atr * 0.1)
         {
            zoneExists = true;
            break;
         }
      }
      
      if(!zoneExists)
      {
         int size = ArraySize(demandBottomPrices);
         ArrayResize(demandTopPrices, size + 1);
         ArrayResize(demandBottomPrices, size + 1);
         ArrayResize(demandIsStrong, size + 1);
         ArrayResize(demandBarIndex, size + 1);
         
         demandBottomPrices[size] = pivotLow;
         demandTopPrices[size] = pivotLow + atr * InpZoneATRMult;
         demandIsStrong[size] = false;
         demandBarIndex[size] = pivotLowBar;
         
         if(ArraySize(demandBottomPrices) > InpMaxDemandZones)
         {
            ArrayRemove(demandTopPrices, 0, 1);
            ArrayRemove(demandBottomPrices, 0, 1);
            ArrayRemove(demandIsStrong, 0, 1);
            ArrayRemove(demandBarIndex, 0, 1);
         }
      }
   }
   
   // Prune old zones
   int currentBar = bars - 1;
   int cutoff = currentBar - InpZoneLookbackBars;
   
   for(int i = ArraySize(supplyBarIndex) - 1; i >= 0; i--)
   {
      if(supplyBarIndex[i] < cutoff)
      {
         ArrayRemove(supplyTopPrices, i, 1);
         ArrayRemove(supplyBottomPrices, i, 1);
         ArrayRemove(supplyIsStrong, i, 1);
         ArrayRemove(supplyBarIndex, i, 1);
      }
   }
   
   for(int i = ArraySize(demandBarIndex) - 1; i >= 0; i--)
   {
      if(demandBarIndex[i] < cutoff)
      {
         ArrayRemove(demandTopPrices, i, 1);
         ArrayRemove(demandBottomPrices, i, 1);
         ArrayRemove(demandIsStrong, i, 1);
         ArrayRemove(demandBarIndex, i, 1);
      }
   }
   
   // Update nearest zones
   UpdateNearestZones();
}

//+------------------------------------------------------------------+
//| Update nearest zones                                             |
//+------------------------------------------------------------------+
void UpdateNearestZones()
{
   double close = iClose(_Symbol, _Period, 0);
   nearestSupplyIdx = -1;
   nearestDemandIdx = -1;
   double nearestSupplyTop = 0;
   double nearestDemandBottom = 0;
   
   // Find nearest supply above price
   for(int i = 0; i < ArraySize(supplyTopPrices); i++)
   {
      if(supplyTopPrices[i] > close)
      {
         if(nearestSupplyIdx < 0 || supplyTopPrices[i] < nearestSupplyTop)
         {
            nearestSupplyIdx = i;
            nearestSupplyTop = supplyTopPrices[i];
         }
      }
   }
   
   // Find nearest demand below price
   for(int i = 0; i < ArraySize(demandBottomPrices); i++)
   {
      if(demandBottomPrices[i] < close)
      {
         if(nearestDemandIdx < 0 || demandBottomPrices[i] > nearestDemandBottom)
         {
            nearestDemandIdx = i;
            nearestDemandBottom = demandBottomPrices[i];
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price is in allowed zone                                |
//+------------------------------------------------------------------+
bool InAllowedSupplyZone(double price)
{
   for(int i = 0; i < ArraySize(supplyTopPrices); i++)
   {
      if(price >= supplyBottomPrices[i] && price <= supplyTopPrices[i])
      {
         bool isHot = (i == nearestSupplyIdx);
         bool isStrong = supplyIsStrong[i];
         bool isNormal = !isStrong && !isHot;
         
         if((isHot && InpAllowHotZones) || 
            (isStrong && InpAllowStrongZones) || 
            (isNormal && InpAllowNormalZones))
            return true;
      }
   }
   return false;
}

bool InAllowedDemandZone(double price)
{
   for(int i = 0; i < ArraySize(demandTopPrices); i++)
   {
      if(price >= demandBottomPrices[i] && price <= demandTopPrices[i])
      {
         bool isHot = (i == nearestDemandIdx);
         bool isStrong = demandIsStrong[i];
         bool isNormal = !isStrong && !isHot;
         
         if((isHot && InpAllowHotZones) || 
            (isStrong && InpAllowStrongZones) || 
            (isNormal && InpAllowNormalZones))
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get touched zone level for invalidation                          |
//+------------------------------------------------------------------+
double GetTouchedDemandBottom(double price)
{
   for(int i = 0; i < ArraySize(demandTopPrices); i++)
   {
      if(price >= demandBottomPrices[i] && price <= demandTopPrices[i])
      {
         bool isHot = (i == nearestDemandIdx);
         bool isStrong = demandIsStrong[i];
         bool isNormal = !isStrong && !isHot;
         
         if((isHot && InpAllowHotZones) || 
            (isStrong && InpAllowStrongZones) || 
            (isNormal && InpAllowNormalZones))
            return demandBottomPrices[i];
      }
   }
   return iLow(_Symbol, _Period, 1);
}

double GetTouchedSupplyTop(double price)
{
   for(int i = 0; i < ArraySize(supplyTopPrices); i++)
   {
      if(price >= supplyBottomPrices[i] && price <= supplyTopPrices[i])
      {
         bool isHot = (i == nearestSupplyIdx);
         bool isStrong = supplyIsStrong[i];
         bool isNormal = !isStrong && !isHot;
         
         if((isHot && InpAllowHotZones) || 
            (isStrong && InpAllowStrongZones) || 
            (isNormal && InpAllowNormalZones))
            return supplyTopPrices[i];
      }
   }
   return iHigh(_Symbol, _Period, 1);
}

//+------------------------------------------------------------------+
//| Check for consecutive candles                                    |
//+------------------------------------------------------------------+
bool ConsecutiveBearish(int n)
{
   for(int i = 1; i <= n; i++)
   {
      double open = iOpen(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      if(close >= open)
         return false;
   }
   return true;
}

bool ConsecutiveBullish(int n)
{
   for(int i = 1; i <= n; i++)
   {
      double open = iOpen(_Symbol, _Period, i);
      double close = iClose(_Symbol, _Period, i);
      if(close <= open)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check for engulfing patterns                                     |
//+------------------------------------------------------------------+
bool BullishEngulfingFlexible()
{
   int bars = Bars(_Symbol, _Period);
   if(bars < InpMinConsecutiveCandles + 1)
      return false;
   
   bool consecutiveBear = ConsecutiveBearish(InpMinConsecutiveCandles);
   double open0 = iOpen(_Symbol, _Period, 0);
   double close0 = iClose(_Symbol, _Period, 0);
   bool currentBull = close0 > open0;
   
   if(!consecutiveBear || !currentBull)
      return false;
   
   double open1 = iOpen(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   
   if(InpUseFlexibleEngulfing)
   {
      double prevSize = MathAbs(close1 - open1);
      double curSize = MathAbs(close0 - open0);
      if(prevSize > 0)
      {
         double coverage = MathMin(curSize, prevSize) / prevSize;
         return (coverage >= InpEngulfingThreshold && open0 < close1 && close0 > open1);
      }
   }
   else
   {
      return (open0 < close1 && close0 > open1);
   }
   
   return false;
}

bool BearishEngulfingFlexible()
{
   int bars = Bars(_Symbol, _Period);
   if(bars < InpMinConsecutiveCandles + 1)
      return false;
   
   bool consecutiveBull = ConsecutiveBullish(InpMinConsecutiveCandles);
   double open0 = iOpen(_Symbol, _Period, 0);
   double close0 = iClose(_Symbol, _Period, 0);
   bool currentBear = close0 < open0;
   
   if(!consecutiveBull || !currentBear)
      return false;
   
   double open1 = iOpen(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   
   if(InpUseFlexibleEngulfing)
   {
      double prevSize = MathAbs(close1 - open1);
      double curSize = MathAbs(close0 - open0);
      if(prevSize > 0)
      {
         double coverage = MathMin(curSize, prevSize) / prevSize;
         return (coverage >= InpEngulfingThreshold && open0 > close1 && close0 < open1);
      }
   }
   else
   {
      return (open0 > close1 && close0 < open1);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get filter parameters based on preset                            |
//+------------------------------------------------------------------+
void GetFilterParams(int &emaLen, int &rsiLen, int &structShort, int &structLong)
{
   if(InpPresetMode == "Auto (Forex)")
   {
      ENUM_TIMEFRAMES period = _Period;
      int periodSeconds = PeriodSeconds(period);
      
      if(periodSeconds == 60)  // M1
      {
         emaLen = 200;
         structShort = 20;
         structLong = 50;
      }
      else if(periodSeconds == 300)  // M5
      {
         emaLen = 200;
         structShort = 14;
         structLong = 35;
      }
      else if(periodSeconds == 900)  // M15
      {
         emaLen = 100;
         structShort = 10;
         structLong = 25;
      }
      else if(periodSeconds == 3600)  // H1
      {
         emaLen = 50;
         structShort = 8;
         structLong = 20;
      }
      else
      {
         emaLen = 100;
         structShort = 10;
         structLong = 25;
      }
      rsiLen = 14;
   }
   else
   {
      emaLen = InpEMALenManual;
      rsiLen = InpRSILenManual;
      structShort = InpStructShortManual;
      structLong = InpStructLongManual;
   }
}

//+------------------------------------------------------------------+
//| Check market structure                                           |
//+------------------------------------------------------------------+
bool CheckMarketStructure(int structShort, int structLong, bool &bullStructure, bool &bearStructure)
{
   double highestHighShort = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, structShort, 1));
   double highestHighLong = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, structLong, 1));
   double lowestLowShort = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, structShort, 1));
   double lowestLowLong = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, structLong, 1));
   
   bullStructure = (highestHighShort > highestHighLong && lowestLowShort > lowestLowLong);
   bearStructure = (lowestLowShort < lowestLowLong && highestHighShort < highestHighLong);
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if candle is strong (directional)                         |
//+------------------------------------------------------------------+
bool IsStrongCandle(int shift, int direction)
{
   // Use closed candles only (shift >= 1)
   if(shift < 1)
      return false;
   
   double open = iOpen(_Symbol, _Period, shift);
   double close = iClose(_Symbol, _Period, shift);
   double high = iHigh(_Symbol, _Period, shift);
   double low = iLow(_Symbol, _Period, shift);
   
   double range = high - low;
   if(range <= 0)
      return false;
   
   double body = MathAbs(close - open);
   double bodyPercent = body / range;
   
   // Body must be >= 60% of range
   if(bodyPercent < 0.60)
      return false;
   
   if(direction == 1)  // Bullish
   {
      // Close must be in top 25% of range
      double closePosition = (close - low) / range;
      if(closePosition < 0.75)
         return false;
      
      // No large opposing wick (upper wick < 20% of range)
      double upperWick = high - MathMax(open, close);
      if(upperWick / range > 0.20)
         return false;
   }
   else  // Bearish
   {
      // Close must be in bottom 25% of range
      double closePosition = (close - low) / range;
      if(closePosition > 0.25)
         return false;
      
      // No large opposing wick (lower wick < 20% of range)
      double lowerWick = MathMin(open, close) - low;
      if(lowerWick / range > 0.20)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check acceptance conditions (swing breakout)                    |
//+------------------------------------------------------------------+
bool CheckAcceptance(int shift, int direction, int lookback = 20)
{
   // Use closed candles only (shift >= 1)
   if(shift < 1)
      return false;
   
   double close = iClose(_Symbol, _Period, shift);
   
   if(direction == 1)  // BUY
   {
      // Candle closes above recent swing high
      int swingHighIdx = iHighest(_Symbol, _Period, MODE_HIGH, lookback, shift + 1);
      if(swingHighIdx < 0)
         return false;
      
      double swingHigh = iHigh(_Symbol, _Period, swingHighIdx);
      if(close <= swingHigh)
         return false;
      
      // Next candle does NOT immediately close back below
      if(shift >= 2)
      {
         double nextClose = iClose(_Symbol, _Period, shift - 1);
         if(nextClose < swingHigh)
            return false;
      }
   }
   else  // SELL
   {
      // Candle closes below recent swing low
      int swingLowIdx = iLowest(_Symbol, _Period, MODE_LOW, lookback, shift + 1);
      if(swingLowIdx < 0)
         return false;
      
      double swingLow = iLow(_Symbol, _Period, swingLowIdx);
      if(close >= swingLow)
         return false;
      
      // Next candle does NOT immediately close back above
      if(shift >= 2)
      {
         double nextClose = iClose(_Symbol, _Period, shift - 1);
         if(nextClose > swingLow)
            return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Candle validation strength-only helper (closed candle only)      |
//+------------------------------------------------------------------+
bool CV_StrengthOnly(const int shift, const int dir)
{
   if(shift < 1)
      return false;
   return IsStrongCandle(shift, dir);
}

//+------------------------------------------------------------------+
//| Check if signal is late (strong impulse before signal)          |
//+------------------------------------------------------------------+
bool CheckLateSignal(datetime signalBarTimeInput, int direction, int lookback = 10)
{
   // Find signal bar index from datetime
   int signalBarIdx = -1;
   for(int i = 1; i < Bars(_Symbol, _Period); i++)
   {
      if(iTime(_Symbol, _Period, i) == signalBarTimeInput)
      {
         signalBarIdx = i;
         break;
      }
   }
   
   if(signalBarIdx < 0)
      return false;  // Signal bar not found
   
   // Check if strong impulse candle occurred BEFORE signal (higher indices = older bars)
   bool foundStrongBefore = false;
   for(int i = signalBarIdx + 1; i <= signalBarIdx + lookback && i < Bars(_Symbol, _Period); i++)
   {
      if(IsStrongCandle(i, direction))
      {
         foundStrongBefore = true;
         break;
      }
   }
   
   if(!foundStrongBefore)
      return false;  // No strong impulse before signal - not late
   
   // Strong impulse before signal - check if NEW strong candle appears AFTER signal
   // Bars after signal: signalBarIdx-1, signalBarIdx-2, ... (lower indices = newer bars)
   bool foundNewStrong = false;
   for(int j = signalBarIdx - 1; j >= 1 && j >= signalBarIdx - MaxWaitBars; j--)
   {
      if(IsStrongCandle(j, direction))
      {
         foundNewStrong = true;
         break;
      }
   }
   
   // Late if strong impulse before signal but no new strong candle after signal
   return !foundNewStrong;
}

//+------------------------------------------------------------------+
//| Validate buy signal                                              |
//+------------------------------------------------------------------+
bool ValidateBuy(datetime signalBarTimeInput, int currentBarIdx)
{
   if(!UseCandleValidation)
      return true;
   
   // Find signal bar index from datetime
   int signalBarIdx = -1;
   for(int i = 1; i < Bars(_Symbol, _Period); i++)
   {
      if(iTime(_Symbol, _Period, i) == signalBarTimeInput)
      {
         signalBarIdx = i;
         break;
      }
   }
   
   if(signalBarIdx < 0)
      return false;  // Signal bar not found
   
   // Signal candle is NEVER entry candle - need at least one bar after signal
   if(currentBarIdx <= signalBarIdx)
      return false;
   
   // Check if we've waited too long
   int barsSinceSignal = currentBarIdx - signalBarIdx;
   if(barsSinceSignal > MaxWaitBars)
   {
      if(InpVerboseLogs)
         Print("CANCEL: BUY signal expired after ", barsSinceSignal, " bars");
      return false;
   }
   
   // Check for opposite strong candle AFTER signal (cancel signal)
   // Bars after signal: signalBarIdx-1, signalBarIdx-2, ... (lower indices = newer bars)
   for(int i = signalBarIdx - 1; i >= 1 && i >= signalBarIdx - MaxWaitBars; i--)
   {
      if(IsStrongCandle(i, -1))  // Strong bearish candle
      {
         if(InpVerboseLogs)
            Print("CANCEL: BUY signal - opposite strong bearish candle at bar ", i);
         return false;
      }
   }
   
   // Check late signal filter
   if(CheckLateSignal(signalBarTimeInput, 1))
   {
      if(InpVerboseLogs)
         Print("CANCEL: BUY signal - late signal (strong impulse before signal, no new strong candle after)");
      return false;
   }
   
   // Check for strong bullish candle AFTER signal (closed bars only)
   bool foundStrongCandle = false;
   int strongCandleIdx = -1;
   
   // Check bars that closed AFTER signal bar (lower indices)
   for(int i = signalBarIdx - 1; i >= 1 && i >= signalBarIdx - MaxWaitBars; i--)
   {
      if(IsStrongCandle(i, 1))  // Strong bullish candle
      {
         foundStrongCandle = true;
         strongCandleIdx = i;
         break;  // Use first (most recent) strong candle found
      }
   }
   
   if(!foundStrongCandle)
   {
      if(InpVerboseLogs)
         Print("WAIT: BUY signal - no strong bullish candle confirmation yet");
      return false;
   }
   
   // Check acceptance conditions on the strong candle
   if(!CheckAcceptance(strongCandleIdx, 1))
   {
      if(InpVerboseLogs)
         Print("WAIT: BUY signal - strong candle found but acceptance conditions not met");
      return false;
   }
   
   if(InpVerboseLogs)
      Print("GO BUY: strong acceptance at bar ", strongCandleIdx);
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate sell signal                                             |
//+------------------------------------------------------------------+
bool ValidateSell(datetime signalBarTimeInput, int currentBarIdx)
{
   if(!UseCandleValidation)
      return true;
   
   // Find signal bar index from datetime
   int signalBarIdx = -1;
   for(int i = 1; i < Bars(_Symbol, _Period); i++)
   {
      if(iTime(_Symbol, _Period, i) == signalBarTimeInput)
      {
         signalBarIdx = i;
         break;
      }
   }
   
   if(signalBarIdx < 0)
      return false;  // Signal bar not found
   
   // Signal candle is NEVER entry candle - need at least one bar after signal
   if(currentBarIdx <= signalBarIdx)
      return false;
   
   // Check if we've waited too long
   int barsSinceSignal = currentBarIdx - signalBarIdx;
   if(barsSinceSignal > MaxWaitBars)
   {
      if(InpVerboseLogs)
         Print("CANCEL: SELL signal expired after ", barsSinceSignal, " bars");
      return false;
   }
   
   // Check for opposite strong candle AFTER signal (cancel signal)
   // Bars after signal: signalBarIdx-1, signalBarIdx-2, ... (lower indices = newer bars)
   for(int i = signalBarIdx - 1; i >= 1 && i >= signalBarIdx - MaxWaitBars; i--)
   {
      if(IsStrongCandle(i, 1))  // Strong bullish candle
      {
         if(InpVerboseLogs)
            Print("CANCEL: SELL signal - opposite strong bullish candle at bar ", i);
         return false;
      }
   }
   
   // Check late signal filter
   if(CheckLateSignal(signalBarTimeInput, -1))
   {
      if(InpVerboseLogs)
         Print("CANCEL: SELL signal - late signal (strong impulse before signal, no new strong candle after)");
      return false;
   }
   
   // Check for strong bearish candle AFTER signal (closed bars only)
   bool foundStrongCandle = false;
   int strongCandleIdx = -1;
   
   // Check bars that closed AFTER signal bar (lower indices)
   for(int i = signalBarIdx - 1; i >= 1 && i >= signalBarIdx - MaxWaitBars; i--)
   {
      if(IsStrongCandle(i, -1))  // Strong bearish candle
      {
         foundStrongCandle = true;
         strongCandleIdx = i;
         break;  // Use first (most recent) strong candle found
      }
   }
   
   if(!foundStrongCandle)
   {
      if(InpVerboseLogs)
         Print("WAIT: SELL signal - no strong bearish candle confirmation yet");
      return false;
   }
   
   // Check acceptance conditions on the strong candle
   if(!CheckAcceptance(strongCandleIdx, -1))
   {
      if(InpVerboseLogs)
         Print("WAIT: SELL signal - strong candle found but acceptance conditions not met");
      return false;
   }
   
   if(InpVerboseLogs)
      Print("GO SELL: strong acceptance at bar ", strongCandleIdx);
   
   return true;
}

//+------------------------------------------------------------------+
//| Check candle validation (state machine)                          |
//+------------------------------------------------------------------+
void CheckCandleValidation()
{
   if(!UseCandleValidation)
      return;
   
   int bars = Bars(_Symbol, _Period);
   int currentBarIdx = bars - 1;  // Current closed bar (bar 1)
   
   // Handle state transitions
   if(currentState == SIGNAL_WAIT_BUY)
   {
      if(ValidateBuy(signalBarTime, currentBarIdx))
      {
         // Validation passed - execute trade
         currentState = SIGNAL_IDLE;
         signalBarTime = 0;
         barsWaited = 0;
         
         // Execute buy directly (validation layer gates execution)
         ExecuteBuySignal();
      }
      else
      {
         // Calculate bars waited for expiry check
         int signalBarIdx = -1;
         for(int i = 1; i < Bars(_Symbol, _Period); i++)
         {
            if(iTime(_Symbol, _Period, i) == signalBarTime)
            {
               signalBarIdx = i;
               break;
            }
         }
         if(signalBarIdx >= 0)
         {
            barsWaited = currentBarIdx - signalBarIdx;
            if(barsWaited > MaxWaitBars)
            {
               // Expiry handled in ValidateBuy, but double-check here
               if(InpVerboseLogs)
                  Print("CANCEL: BUY signal expired after ", barsWaited, " bars");
               currentState = SIGNAL_IDLE;
               signalBarTime = 0;
               barsWaited = 0;
            }
         }
      }
   }
   else if(currentState == SIGNAL_WAIT_SELL)
   {
      if(ValidateSell(signalBarTime, currentBarIdx))
      {
         // Validation passed - execute trade
         currentState = SIGNAL_IDLE;
         signalBarTime = 0;
         barsWaited = 0;
         
         // Execute sell directly (validation layer gates execution)
         ExecuteSellSignal();
      }
      else
      {
         // Calculate bars waited for expiry check
         int signalBarIdx = -1;
         for(int i = 1; i < Bars(_Symbol, _Period); i++)
         {
            if(iTime(_Symbol, _Period, i) == signalBarTime)
            {
               signalBarIdx = i;
               break;
            }
         }
         if(signalBarIdx >= 0)
         {
            barsWaited = currentBarIdx - signalBarIdx;
            if(barsWaited > MaxWaitBars)
            {
               // Expiry handled in ValidateSell, but double-check here
               if(InpVerboseLogs)
                  Print("CANCEL: SELL signal expired after ", barsWaited, " bars");
               currentState = SIGNAL_IDLE;
               signalBarTime = 0;
               barsWaited = 0;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Candle metrics                            |
//+------------------------------------------------------------------+
double PSV_Body(int shift)
{
   if(shift < 0 || shift >= Bars(_Symbol, _Period))
      return 0.0;
   return MathAbs(iClose(_Symbol, _Period, shift) - iOpen(_Symbol, _Period, shift));
}

double PSV_Range(int shift)
{
   if(shift < 0 || shift >= Bars(_Symbol, _Period))
      return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double high = iHigh(_Symbol, _Period, shift);
   double low = iLow(_Symbol, _Period, shift);
   return MathMax(high - low, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
}

double PSV_UpperWick(int shift)
{
   if(shift < 0 || shift >= Bars(_Symbol, _Period))
      return 0.0;
   double high = iHigh(_Symbol, _Period, shift);
   double open = iOpen(_Symbol, _Period, shift);
   double close = iClose(_Symbol, _Period, shift);
   return high - MathMax(open, close);
}

double PSV_LowerWick(int shift)
{
   if(shift < 0 || shift >= Bars(_Symbol, _Period))
      return 0.0;
   double low = iLow(_Symbol, _Period, shift);
   double open = iOpen(_Symbol, _Period, shift);
   double close = iClose(_Symbol, _Period, shift);
   return MathMin(open, close) - low;
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Strength check                            |
//+------------------------------------------------------------------+
bool PSV_IsStrongCandle(int shift, int dir)
{
   if(shift < 1 || shift >= Bars(_Symbol, _Period))
      return false;
   
   double body = PSV_Body(shift);
   double range = PSV_Range(shift);
   if(range <= 0)
      return false;
   
   double bodyRatio = body / range;
   if(bodyRatio < PSV_StrongBodyRatio)
      return false;
   
   double close = iClose(_Symbol, _Period, shift);
   double high = iHigh(_Symbol, _Period, shift);
   double low = iLow(_Symbol, _Period, shift);
   
   if(dir == 1)  // BUY
   {
      double closeNearHigh = (high - close) / range;
      if(closeNearHigh > PSV_CloseNearExtreme)
         return false;
      
      double upperWick = PSV_UpperWick(shift);
      double oppWickRatio = upperWick / range;
      if(oppWickRatio > (1.0 - PSV_StrongBodyRatio))
         return false;
   }
   else  // SELL
   {
      double closeNearLow = (close - low) / range;
      if(closeNearLow > PSV_CloseNearExtreme)
         return false;
      
      double lowerWick = PSV_LowerWick(shift);
      double oppWickRatio = lowerWick / range;
      if(oppWickRatio > (1.0 - PSV_StrongBodyRatio))
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Average body calculation                  |
//+------------------------------------------------------------------+
double PSV_AvgBody(int fromShift, int period)
{
   if(fromShift < 0 || fromShift + period - 1 >= Bars(_Symbol, _Period))
      return 0.0;
   
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < period; i++)
   {
      int shift = fromShift + i;
      if(shift >= Bars(_Symbol, _Period))
         break;
      sum += PSV_Body(shift);
      count++;
   }
   
   if(count == 0)
      return 0.0;
   return sum / count;
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Displacement check                       |
//+------------------------------------------------------------------+
bool PSV_IsDisplacement(int shift, bool isLateSignal = false)
{
   // NOTE: isLateSignal is kept for backward compatibility but late handling is binary in PSV_CheckAcceptance.
   if(isLateSignal)
   {
      // no-op: parameter preserved for compatibility
   }
   if(shift < 1 || shift >= Bars(_Symbol, _Period))
      return false;

   double body = PSV_Body(shift);
   double avgBody = PSV_AvgBody(shift + 1, PSV_AvgBodyPeriod);

   if(avgBody <= 0)
      return false;

   double threshold = PSV_DisplacementMult;
   return (body >= threshold * avgBody);
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Late-signal binary invalidation           |
//| Late if there is a pre-signal displacement candle in same dir.   |
//| Require at least 1 non-displacement cooldown candle before entry |
//+------------------------------------------------------------------+
bool PSV_IsLateAndNoCooldown(int dir, int signalBarIdx, bool &isLateSignal)
{
   isLateSignal = false;
   int bars = Bars(_Symbol, _Period);
   if(signalBarIdx < 0 || signalBarIdx >= bars)
      return false;

   // Find most recent displacement candle in same direction BEFORE the signal bar
   int impulseIdx = -1;
   int maxI = MathMin(signalBarIdx + PSV_SwingLookback, bars - 1);
   for(int i = signalBarIdx + 1; i <= maxI; i++)
   {
      if(!PSV_IsDisplacement(i, false))
         continue;

      double o = iOpen(_Symbol, _Period, i);
      double c = iClose(_Symbol, _Period, i);
      if((dir == 1 && c > o) || (dir == -1 && c < o))
      {
         impulseIdx = i;
         break;
      }
   }

   if(impulseIdx < 0)
      return false; // not late

   isLateSignal = true;

   // Require at least one cooldown candle between impulse and acceptance candle (bar 1)
   bool hasCooldown = false;
   for(int j = impulseIdx - 1; j >= 1; j--)
   {
      bool sameDirDisplacement = false;
      if(PSV_IsDisplacement(j, false))
      {
         double o = iOpen(_Symbol, _Period, j);
         double c = iClose(_Symbol, _Period, j);
         if((dir == 1 && c > o) || (dir == -1 && c < o))
            sameDirDisplacement = true;
      }

      if(!sameDirDisplacement)
      {
         hasCooldown = true;
         break;
      }
   }

   return (!hasCooldown); // late + no cooldown => invalidate
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Effective wait bars by timeframe          |
//+------------------------------------------------------------------+
int PSV_EffectiveMaxWaitBars()
{
   if(_Period == PERIOD_M1 || _Period == PERIOD_M2 || _Period == PERIOD_M3 || _Period == PERIOD_M4 || _Period == PERIOD_M5)
      return 3;
   return PSV_MaxWaitBars;
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Structure level detection                |
//+------------------------------------------------------------------+
double PSV_RecentSwingHigh(int fromShift, int lookback)
{
   if(fromShift < 0 || fromShift + lookback - 1 >= Bars(_Symbol, _Period))
      return 0.0;
   
   int idx = iHighest(_Symbol, _Period, MODE_HIGH, lookback, fromShift);
   if(idx < 0)
      return 0.0;
   return iHigh(_Symbol, _Period, idx);
}

double PSV_RecentSwingLow(int fromShift, int lookback)
{
   if(fromShift < 0 || fromShift + lookback - 1 >= Bars(_Symbol, _Period))
      return 0.0;
   
   int idx = iLowest(_Symbol, _Period, MODE_LOW, lookback, fromShift);
   if(idx < 0)
      return 0.0;
   return iLow(_Symbol, _Period, idx);
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Check acceptance                          |
//+------------------------------------------------------------------+
bool PSV_CheckAcceptance(int dir, double &acceptLevel, bool &isLateSignal)
{
   int bars = Bars(_Symbol, _Period);
   if(bars < PSV_SwingLookback + 3)
      return false;
   
   // Late-signal binary invalidation (requires cooldown candle)
isLateSignal = false;
if(psv_signal_bar_time > 0)
{
   int signalBarIdx = -1;
   for(int i = 1; i < bars; i++)
   {
      if(iTime(_Symbol, _Period, i) == psv_signal_bar_time)
      {
         signalBarIdx = i;
         break;
      }
   }

   if(signalBarIdx >= 0)
   {
      bool lateNoCooldown = PSV_IsLateAndNoCooldown(dir, signalBarIdx, isLateSignal);
      if(lateNoCooldown)
         return false;
   }
}
   // Check acceptance on bar 1 (just closed)
   if(dir == 1)  // BUY
   {
      acceptLevel = PSV_RecentSwingHigh(2, PSV_SwingLookback);
      if(acceptLevel <= 0)
         return false;
      
      double close1 = iClose(_Symbol, _Period, 1);
      if(close1 <= acceptLevel)
         return false;
      
      if(!PSV_IsStrongCandle(1, 1))
         return false;
      
      if(!PSV_IsDisplacement(1, false))
         return false;

      if(UseCandleValidation && !CV_StrengthOnly(1, 1))
         return false;
      
      return true;
   }
   else  // SELL
   {
      acceptLevel = PSV_RecentSwingLow(2, PSV_SwingLookback);
      if(acceptLevel <= 0)
         return false;
      
      double close1 = iClose(_Symbol, _Period, 1);
      if(close1 >= acceptLevel)
         return false;
      
      if(!PSV_IsStrongCandle(1, -1))
         return false;
      
      if(!PSV_IsDisplacement(1, false))
         return false;

      if(UseCandleValidation && !CV_StrengthOnly(1, -1))
         return false;
      
      return true;
   }
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Find fresh origin zone                    |
//+------------------------------------------------------------------+
bool PSV_FindFreshOriginZone(int dir, double &freshLow, double &freshHigh)
{
   int bars = Bars(_Symbol, _Period);
   if(bars < PSV_FreshLevelLookback + 3)
      return false;
   
   // Find origin candle: last (most recent) opposite-color candle before acceptance candle (bar 1)
   // Start from shift=2 (bar before acceptance) and scan backward
   int originShift = -1;
   int maxLookback = MathMin(PSV_FreshLevelLookback + 1, bars - 1);
   
   if(dir == 1)  // BUY: find last bearish candle before bar 1
   {
      for(int i = 2; i <= maxLookback && i < bars; i++)
      {
         double open = iOpen(_Symbol, _Period, i);
         double close = iClose(_Symbol, _Period, i);
         if(close < open)
         {
            originShift = i;  // Found most recent bearish candle
            break;  // Stop at first (most recent) match
         }
      }
   }
   else  // SELL: find last bullish candle before bar 1
   {
      for(int i = 2; i <= maxLookback && i < bars; i++)
      {
         double open = iOpen(_Symbol, _Period, i);
         double close = iClose(_Symbol, _Period, i);
         if(close > open)
         {
            originShift = i;  // Found most recent bullish candle
            break;  // Stop at first (most recent) match
         }
      }
   }
   
   if(originShift < 0)
      return false;
   
   freshLow = iLow(_Symbol, _Period, originShift);
   freshHigh = iHigh(_Symbol, _Period, originShift);
   
   // Get ATR for tolerance
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return false;
   double atr = atrBuffer[0];
   double tol = atr * PSV_FreshTouchATRFrac;
   
   // Check freshness: zone must not have been touched since creation
   for(int i = originShift - 1; i >= 1; i--)
   {
      double high = iHigh(_Symbol, _Period, i);
      double low = iLow(_Symbol, _Period, i);
      
      if(high >= freshLow - tol && low <= freshHigh + tol)
         return false;  // Zone was touched, not fresh
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Check retest condition                    |
//+------------------------------------------------------------------+
bool PSV_CheckRetest(int dir, double freshLow, double freshHigh)
{
   int bars = Bars(_Symbol, _Period);
   if(bars < 2)
      return false;
   
   // Get ATR for tolerance
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return false;
   double atr = atrBuffer[0];
   double tol = atr * PSV_FreshTouchATRFrac;
   
   double low1 = iLow(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   
   if(dir == 1)  // BUY: require price came back into/near zone
   {
      return (low1 <= freshHigh + tol);
   }
   else  // SELL: require price came back into/near zone
   {
      return (high1 >= freshLow - tol);
   }
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: No-reclaim check                          |
//+------------------------------------------------------------------+
bool PSV_NoReclaimHolds(int dir, double level)
{
   if(!PSV_RequireNoReclaim)
      return true;
   
   int bars = Bars(_Symbol, _Period);
   if(bars < 2)
      return false;
   
   // Get ATR for tolerance
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return false;
   double atr = atrBuffer[0];
   double tol = atr * PSV_FreshTouchATRFrac;
   
   double close1 = iClose(_Symbol, _Period, 1);
   
   if(dir == 1)  // BUY: require Close[1] >= level - tol
   {
      return (close1 >= level - tol);
   }
   else  // SELL: require Close[1] <= level + tol
   {
      return (close1 <= level + tol);
   }
}

//+------------------------------------------------------------------+
//| Post-Signal Validator: Main validation logic                     |
//+------------------------------------------------------------------+
void PSV_CheckValidation()
{
   if(!UsePostSignalValidator)
      return;
   
   // Only process if in WAIT state
   if(psv_state == PSV_IDLE)
      return;
   
   int bars = Bars(_Symbol, _Period);
   if(bars < PSV_SwingLookback + 3)
      return;
   
   // Handle WAIT_BUY state
   if(psv_state == PSV_WAIT_BUY)
   {
      psv_waited++;
      int eff = PSV_EffectiveMaxWaitBars();
      
      // Check expiry (but allow hold check if acceptance was already found)
      if(psv_waited > eff && !psv_pending_hold_check)
      {
         if(PSV_EnableLogs)
            Print("PSV CANCEL reason=expired BUY waited=", psv_waited);
         psv_state = PSV_IDLE;
         psv_signal_bar_time = 0;
         psv_waited = 0;
         psv_pending_hold_check = false;
         return;
      }
      
      // Hard limit: even with pending hold check, cancel if waited too long
      if(psv_waited > eff + 1)
      {
         if(PSV_EnableLogs)
            Print("PSV CANCEL reason=hard limit exceeded BUY waited=", psv_waited);
         psv_state = PSV_IDLE;
         psv_signal_bar_time = 0;
         psv_waited = 0;
         psv_pending_hold_check = false;
         return;
      }
      
      // Check opposite strong candle (immediate invalidation)
      if(PSV_IsStrongCandle(1, -1) && PSV_IsDisplacement(1, false))
      {
         if(PSV_EnableLogs)
            Print("PSV CANCEL reason=opposite strong bearish candle");
         psv_state = PSV_IDLE;
         psv_signal_bar_time = 0;
         psv_waited = 0;
         psv_pending_hold_check = false;
         return;
      }
      
      // Check hold condition if pending
      if(psv_pending_hold_check)
      {
         if(!PSV_NoReclaimHolds(1, psv_accept_level))
         {
            if(PSV_EnableLogs)
               Print("PSV CANCEL reason=reclaim BUY level=", psv_accept_level);
            psv_state = PSV_IDLE;
            psv_signal_bar_time = 0;
            psv_waited = 0;
            psv_pending_hold_check = false;
            return;
         }
         
         // GO logic after hold passes
if(!PSV_RequireRetest)
{
   // GO BUY (no retest required)
   if(PSV_EnableLogs)
      Print("PSV GO BUY");
   psv_state = PSV_IDLE;
   psv_signal_bar_time = 0;
   psv_waited = 0;
   psv_pending_hold_check = false;
   ExecuteBuySignal();
   return;
}

// Optional retest requirement
if(PSV_CheckRetest(1, psv_fresh_low, psv_fresh_high))
{
   // GO BUY
   if(PSV_EnableLogs)
      Print("PSV GO BUY");
   psv_state = PSV_IDLE;
   psv_signal_bar_time = 0;
   psv_waited = 0;
   psv_pending_hold_check = false;
   ExecuteBuySignal();
   return;
}}
      else
      {
         // Check acceptance
         double acceptLevel = 0.0;
         bool isLateSignal = false;
         if(PSV_CheckAcceptance(1, acceptLevel, isLateSignal))
         {
            psv_accept_level = acceptLevel;
            
            // Find fresh origin zone
            double freshLow = 0.0, freshHigh = 0.0;
            if(!PSV_FindFreshOriginZone(1, freshLow, freshHigh))
            {
               if(PSV_EnableLogs)
                  Print("PSV CANCEL reason=not fresh BUY");
               psv_state = PSV_IDLE;
               psv_signal_bar_time = 0;
               psv_waited = 0;
               return;
            }
            
            psv_fresh_low = freshLow;
            psv_fresh_high = freshHigh;

            // Optional: enter immediately on acceptance (only if no-reclaim is disabled)
            if(PSV_EnterOnAcceptance && !PSV_RequireNoReclaim)
            {
               if(PSV_EnableLogs)
                  Print("PSV GO BUY (on acceptance)");
               psv_state = PSV_IDLE;
               psv_signal_bar_time = 0;
               psv_waited = 0;
               psv_pending_hold_check = false;
               ExecuteBuySignal();
               return;
            }

            // Set pending hold check
            psv_pending_hold_check = true;
            if(PSV_EnableLogs)
               Print("PSV ACCEPT BUY level=", acceptLevel);
         }
      }
   }
   
   // Handle WAIT_SELL state
   else if(psv_state == PSV_WAIT_SELL)
   {
      psv_waited++;
      int eff = PSV_EffectiveMaxWaitBars();
      
      // Check expiry (but allow hold check if acceptance was already found)
      if(psv_waited > eff && !psv_pending_hold_check)
      {
         if(PSV_EnableLogs)
            Print("PSV CANCEL reason=expired SELL waited=", psv_waited);
         psv_state = PSV_IDLE;
         psv_signal_bar_time = 0;
         psv_waited = 0;
         psv_pending_hold_check = false;
         return;
      }
      
      // Hard limit: even with pending hold check, cancel if waited too long
      if(psv_waited > eff + 1)
      {
         if(PSV_EnableLogs)
            Print("PSV CANCEL reason=hard limit exceeded SELL waited=", psv_waited);
         psv_state = PSV_IDLE;
         psv_signal_bar_time = 0;
         psv_waited = 0;
         psv_pending_hold_check = false;
         return;
      }
      
      // Check opposite strong candle (immediate invalidation)
      if(PSV_IsStrongCandle(1, 1) && PSV_IsDisplacement(1, false))
      {
         if(PSV_EnableLogs)
            Print("PSV CANCEL reason=opposite strong bullish candle");
         psv_state = PSV_IDLE;
         psv_signal_bar_time = 0;
         psv_waited = 0;
         psv_pending_hold_check = false;
         return;
      }
      
      // Check hold condition if pending
      if(psv_pending_hold_check)
      {
         if(!PSV_NoReclaimHolds(-1, psv_accept_level))
         {
            if(PSV_EnableLogs)
               Print("PSV CANCEL reason=reclaim SELL level=", psv_accept_level);
            psv_state = PSV_IDLE;
            psv_signal_bar_time = 0;
            psv_waited = 0;
            psv_pending_hold_check = false;
            return;
         }
         
         // GO logic after hold passes
if(!PSV_RequireRetest)
{
   // GO SELL (no retest required)
   if(PSV_EnableLogs)
      Print("PSV GO SELL");
   psv_state = PSV_IDLE;
   psv_signal_bar_time = 0;
   psv_waited = 0;
   psv_pending_hold_check = false;
   ExecuteSellSignal();
   return;
}

// Optional retest requirement
if(PSV_CheckRetest(-1, psv_fresh_low, psv_fresh_high))
{
   // GO SELL
   if(PSV_EnableLogs)
      Print("PSV GO SELL");
   psv_state = PSV_IDLE;
   psv_signal_bar_time = 0;
   psv_waited = 0;
   psv_pending_hold_check = false;
   ExecuteSellSignal();
   return;
}}
      else
      {
         // Check acceptance
         double acceptLevel = 0.0;
         bool isLateSignal = false;
         if(PSV_CheckAcceptance(-1, acceptLevel, isLateSignal))
         {
            psv_accept_level = acceptLevel;
            
            // Find fresh origin zone
            double freshLow = 0.0, freshHigh = 0.0;
            if(!PSV_FindFreshOriginZone(-1, freshLow, freshHigh))
            {
               if(PSV_EnableLogs)
                  Print("PSV CANCEL reason=not fresh SELL");
               psv_state = PSV_IDLE;
               psv_signal_bar_time = 0;
               psv_waited = 0;
               return;
            }
            
            psv_fresh_low = freshLow;
            psv_fresh_high = freshHigh;

            // Optional: enter immediately on acceptance (only if no-reclaim is disabled)
            if(PSV_EnterOnAcceptance && !PSV_RequireNoReclaim)
            {
               if(PSV_EnableLogs)
                  Print("PSV GO SELL (on acceptance)");
               psv_state = PSV_IDLE;
               psv_signal_bar_time = 0;
               psv_waited = 0;
               psv_pending_hold_check = false;
               ExecuteSellSignal();
               return;
            }

            // Set pending hold check
            psv_pending_hold_check = true;
            if(PSV_EnableLogs)
               Print("PSV ACCEPT SELL level=", acceptLevel);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for final signals (plotBuy/plotSell)                      |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   // Use bar index 1 (closed bar) for signal detection
   int bars = Bars(_Symbol, _Period);
   if(bars < 50)
      return;
   
   // Check direction lock
   int currentBarIndex = bars - 1;
   if(lastDetectedSignalBarIndex >= 0 && (currentBarIndex - lastDetectedSignalBarIndex) < Wait_Between_Signals)
      return;
   
   // Check one signal per bar
   if(InpOneSignalPerBar && lastDetectedSignalBarIndex == currentBarIndex)
      return;
   
   // Get filter parameters
   int emaLen, rsiLen, structShort, structLong;
   GetFilterParams(emaLen, rsiLen, structShort, structLong);
   
   // Get indicators
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 2, atrBuffer) <= 0)
      return;
   
   // Create/release EMA handle if needed
   static int lastEMALen = 0;
   if(emaHandle == INVALID_HANDLE || emaLen != lastEMALen)
   {
      if(emaHandle != INVALID_HANDLE)
         IndicatorRelease(emaHandle);
      emaHandle = iMA(_Symbol, _Period, emaLen, 0, MODE_EMA, PRICE_CLOSE);
      lastEMALen = emaLen;
      if(emaHandle == INVALID_HANDLE)
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to create EMA handle");
         return;
      }
   }
   
   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   int emaBufferCopied = CopyBuffer(emaHandle, 0, 0, 3, emaBuffer);
   bool emaBufferOK = (emaBufferCopied >= 3);
   if(!emaBufferOK)
   {
      if(InpVerboseLogs)
         Print("WARNING: Failed to copy EMA buffer (got ", emaBufferCopied, " values, need 3). Skipping slope filtering for this bar.");
      // Do not block all trades - continue without slope filtering
   }
   
   // Get current prices (bar index 1 = closed bar, bar index 0 = current forming bar)
   double open1 = iOpen(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);
   double open0 = iOpen(_Symbol, _Period, 0);
   double close0 = iClose(_Symbol, _Period, 0);
   
   // Check engulfing patterns on bar 1 (closed bar)
   // Need to check bar 1 engulfing by looking at bar 1 and bar 2
   bool bullEngulf = false;
   bool bearEngulf = false;
   bool bullFlexPrev = false;
   bool bearFlexPrev = false;
   
   // Check if bar 1 had bullish engulfing (compare bar 1 with bar 2)
   if(bars >= InpMinConsecutiveCandles + 2)
   {
      double open2 = iOpen(_Symbol, _Period, 2);
      double close2 = iClose(_Symbol, _Period, 2);
      
      // Check consecutive bearish before bar 1
      bool consecutiveBear = true;
      for(int i = 2; i <= InpMinConsecutiveCandles + 1; i++)
      {
         double o = iOpen(_Symbol, _Period, i);
         double c = iClose(_Symbol, _Period, i);
         if(c >= o)
         {
            consecutiveBear = false;
            break;
         }
      }
      
      // Check if bar 1 is bullish engulfing bar 2
      if(consecutiveBear && close1 > open1)
      {
         if(InpUseFlexibleEngulfing)
         {
            double prevSize = MathAbs(close2 - open2);
            double curSize = MathAbs(close1 - open1);
            if(prevSize > 0)
            {
               double coverage = MathMin(curSize, prevSize) / prevSize;
               if(coverage >= InpEngulfingThreshold && open1 < close2 && close1 > open2)
                  bullFlexPrev = true;
            }
         }
         else
         {
            if(open1 < close2 && close1 > open2)
               bullFlexPrev = true;
         }
      }
      
      // Check consecutive bullish before bar 1
      bool consecutiveBull = true;
      for(int i = 2; i <= InpMinConsecutiveCandles + 1; i++)
      {
         double o = iOpen(_Symbol, _Period, i);
         double c = iClose(_Symbol, _Period, i);
         if(c <= o)
         {
            consecutiveBull = false;
            break;
         }
      }
      
      // Check if bar 1 is bearish engulfing bar 2
      if(consecutiveBull && close1 < open1)
      {
         if(InpUseFlexibleEngulfing)
         {
            double prevSize = MathAbs(close2 - open2);
            double curSize = MathAbs(close1 - open1);
            if(prevSize > 0)
            {
               double coverage = MathMin(curSize, prevSize) / prevSize;
               if(coverage >= InpEngulfingThreshold && open1 > close2 && close1 < open2)
                  bearFlexPrev = true;
            }
         }
         else
         {
            if(open1 > close2 && close1 < open2)
               bearFlexPrev = true;
         }
      }
   }
   
   bullEngulf = bullFlexPrev;
   bearEngulf = bearFlexPrev;
   
   // Consecutive arrows: For strict bar-close logic, check if bar 2 had engulfing and bar 1 confirms
   // Pine script: bullConsec = bullFlex[1] and (close > open) - evaluated on bar close
   // MQL5 bar-close: bar 2 had engulfing, bar 1 (just closed) confirms same direction
   bool bullConsec = false;
   bool bearConsec = false;
   
   if(InpShowConsecutiveArrows && bars >= InpMinConsecutiveCandles + 3)
   {
      // Check if bar 2 had bullish engulfing (compare bar 2 with bar 3)
      double open2 = iOpen(_Symbol, _Period, 2);
      double close2 = iClose(_Symbol, _Period, 2);
      double open3 = iOpen(_Symbol, _Period, 3);
      double close3 = iClose(_Symbol, _Period, 3);
      
      bool bullFlexBar2 = false;
      bool bearFlexBar2 = false;
      
      // Check consecutive bearish before bar 2
      bool consecutiveBearBar2 = true;
      for(int i = 3; i <= InpMinConsecutiveCandles + 2; i++)
      {
         double o = iOpen(_Symbol, _Period, i);
         double c = iClose(_Symbol, _Period, i);
         if(c >= o)
         {
            consecutiveBearBar2 = false;
            break;
         }
      }
      
      if(consecutiveBearBar2 && close2 > open2)
      {
         if(InpUseFlexibleEngulfing)
         {
            double prevSize = MathAbs(close3 - open3);
            double curSize = MathAbs(close2 - open2);
            if(prevSize > 0)
            {
               double coverage = MathMin(curSize, prevSize) / prevSize;
               if(coverage >= InpEngulfingThreshold && open2 < close3 && close2 > open3)
                  bullFlexBar2 = true;
            }
         }
         else
         {
            if(open2 < close3 && close2 > open3)
               bullFlexBar2 = true;
         }
      }
      
      // Check consecutive bullish before bar 2
      bool consecutiveBullBar2 = true;
      for(int i = 3; i <= InpMinConsecutiveCandles + 2; i++)
      {
         double o = iOpen(_Symbol, _Period, i);
         double c = iClose(_Symbol, _Period, i);
         if(c <= o)
         {
            consecutiveBullBar2 = false;
            break;
         }
      }
      
      if(consecutiveBullBar2 && close2 < open2)
      {
         if(InpUseFlexibleEngulfing)
         {
            double prevSize = MathAbs(close3 - open3);
            double curSize = MathAbs(close2 - open2);
            if(prevSize > 0)
            {
               double coverage = MathMin(curSize, prevSize) / prevSize;
               if(coverage >= InpEngulfingThreshold && open2 > close3 && close2 < open3)
                  bearFlexBar2 = true;
            }
         }
         else
         {
            if(open2 > close3 && close2 < open3)
               bearFlexBar2 = true;
         }
      }
      
      // Consecutive confirmation based on mode
      if(InpStrictBarCloseMode)
      {
         // Strict bar-close: bar 2 had engulfing, bar 1 (just closed) confirms same direction
         if(bullFlexBar2 && close1 > open1)
            bullConsec = true;
         if(bearFlexBar2 && close1 < open1)
            bearConsec = true;
      }
      else
      {
         // Intrabar mode: bar 1 had engulfing, bar 0 (current forming) confirms same direction
         // Note: This can repaint but matches Pine script behavior more closely
         if(bullFlexPrev && close0 > open0)
            bullConsec = true;
         if(bearFlexPrev && close0 < open0)
            bearConsec = true;
      }
   }
   else if(InpShowConsecutiveArrows && !InpStrictBarCloseMode)
   {
      // Intrabar mode fallback: use bar 1 engulfing with bar 0 confirmation
      if(bullFlexPrev && close0 > open0)
         bullConsec = true;
      if(bearFlexPrev && close0 < open0)
         bearConsec = true;
   }
   
   // Zone touch price
   double buyPx = (InpZoneTouchMode == "Close") ? close1 : low1;
   double sellPx = (InpZoneTouchMode == "Close") ? close1 : high1;
   
   // Orange in zone signals
   bool buyOrangeInZone = bullConsec && InAllowedDemandZone(buyPx);
   bool sellOrangeInZone = bearConsec && InAllowedSupplyZone(sellPx);
   
   // Combine raw signals
   bool rawBullSignal = bullEngulf || bullConsec || buyOrangeInZone;
   bool rawBearSignal = bearEngulf || bearConsec || sellOrangeInZone;
   
   // Quality filter - Full Pine Script Implementation
   bool qualityBullOK = true;
   bool qualityBearOK = true;
   
   if(InpUseQualityFilter)
   {
      bool qualityDataOK = true;
      double emaQuality = 0.0;
      double emaQualityPrev = 0.0;
      
      // Check if we need quality EMA instead
      if(InpQualityEMALen != emaLen)
      {
         int emaQualityHandle = iMA(_Symbol, _Period, InpQualityEMALen, 0, MODE_EMA, PRICE_CLOSE);
         if(emaQualityHandle != INVALID_HANDLE)
         {
            double emaQualityBuffer[];
            ArraySetAsSeries(emaQualityBuffer, true);
            int copied = CopyBuffer(emaQualityHandle, 0, 0, 3, emaQualityBuffer);
            if(copied >= 3)
            {
               emaQuality = emaQualityBuffer[1];      // Current closed bar
               emaQualityPrev = emaQualityBuffer[2];  // Previous closed bar
            }
            else
            {
               qualityDataOK = false; // fail-open for this bar
               if(InpVerboseLogs)
                  Print("WARNING: Quality EMA buffer insufficient (got ", copied, " values, need 3). Skipping quality slope check this bar (fail-open).");
            }
            IndicatorRelease(emaQualityHandle);
         }
         else
         {
            qualityDataOK = false; // handle creation failed - fail-open
            if(InpVerboseLogs)
               Print("WARNING: Failed to create quality EMA handle. Skipping quality slope check this bar (fail-open).");
         }
      }
      else
      {
         // Use existing trend EMA buffer if sufficient
         if(emaBufferOK && MathIsValidNumber(emaBuffer[1]) && MathIsValidNumber(emaBuffer[2]))
         {
            emaQuality = emaBuffer[1];      // Current closed bar
            emaQualityPrev = emaBuffer[2];  // Previous closed bar
         }
         else
         {
            qualityDataOK = false; // fail-open
            if(InpVerboseLogs)
               Print("WARNING: Trend EMA buffer insufficient for quality (emaBufferCopied=", emaBufferCopied, "). Skipping quality slope check this bar (fail-open).");
         }
      }
      
      if(qualityDataOK)
      {
         bool emaQualityRising = (emaQuality >= emaQualityPrev);
         bool emaQualityFalling = (emaQuality <= emaQualityPrev);
         
         qualityBullOK = (close1 > emaQuality && emaQualityRising);
         qualityBearOK = (close1 < emaQuality && emaQualityFalling);
      }
      else
      {
         // Fail-open: do not block trades when data is insufficient
         qualityBullOK = true;
         qualityBearOK = true;
      }
   }
   
   // Spacing filter (already checked above)
   bool spacingBullOK = true;
   bool spacingBearOK = true;
   
   // Direction lock: block opposite direction within lock window
   if(lastDetectedSignalBarIndex >= 0)
   {
      int barsSinceSignal = currentBarIndex - lastDetectedSignalBarIndex;
      if(barsSinceSignal < Wait_Between_Signals)
      {
         spacingBullOK = false;
         spacingBearOK = false;
      }
   }
   
   // Priority-based signal selection (matching Pine script)
   // Priority: Reversal > Engulfing > Continuation > Orange
   // For now, we only have Engulfing and Orange, so:
   bool hasEngulfingBull = bullEngulf || bullConsec;
   bool hasEngulfingBear = bearEngulf || bearConsec;
   
   bool selectedBullSignal = false;
   bool selectedBearSignal = false;
   
   if(rawBullSignal)
   {
      if(hasEngulfingBull)
         selectedBullSignal = true;
      else if(buyOrangeInZone)
         selectedBullSignal = true;
   }
   
   if(rawBearSignal)
   {
      if(hasEngulfingBear)
         selectedBearSignal = true;
      else if(sellOrangeInZone)
         selectedBearSignal = true;
   }
   
   // Base filtered signals (quality + spacing)
   bool baseBullOK = selectedBullSignal && qualityBullOK && spacingBullOK;
   bool baseBearOK = selectedBearSignal && qualityBearOK && spacingBearOK;
   
   // Filtered signals
   bool filteredBullSignal = baseBullOK;
   bool filteredBearSignal = baseBearOK;
   
   // Filter mode check - Full Pine Script Implementation
   bool buyFilterOK = true;
   bool sellFilterOK = true;
   
   // Get RSI if needed
   double rsiValue = 50.0;
   if(InpFilterMode == "RSI Momentum" || InpFilterMode == "EMA + RSI")
   {
      if(rsiHandle == INVALID_HANDLE || rsiHandle != iRSI(_Symbol, _Period, rsiLen, PRICE_CLOSE))
      {
         if(rsiHandle != INVALID_HANDLE)
            IndicatorRelease(rsiHandle);
         rsiHandle = iRSI(_Symbol, _Period, rsiLen, PRICE_CLOSE);
      }
      
      if(rsiHandle != INVALID_HANDLE)
      {
         double rsiBuffer[];
         ArraySetAsSeries(rsiBuffer, true);
         if(CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer) > 0)
            rsiValue = rsiBuffer[0];
      }
   }
   
   // Apply filter mode (matching Pine script exactly)
   if(InpFilterMode == "None")
   {
      buyFilterOK = true;
      sellFilterOK = true;
   }
   else if(InpFilterMode == "EMA Trend")
   {
      buyFilterOK = (close1 > emaBuffer[1]);
      sellFilterOK = (close1 < emaBuffer[1]);
   }
   else if(InpFilterMode == "RSI Momentum")
   {
      buyFilterOK = (rsiValue > InpRSIMid);
      sellFilterOK = (rsiValue < InpRSIMid);
   }
   else if(InpFilterMode == "Market Structure")
   {
      bool bullStruct, bearStruct;
      CheckMarketStructure(structShort, structLong, bullStruct, bearStruct);
      buyFilterOK = bullStruct;
      sellFilterOK = bearStruct;
   }
   else if(InpFilterMode == "EMA + RSI")
   {
      buyFilterOK = (close1 > emaBuffer[1] && rsiValue > InpRSIMid);
      sellFilterOK = (close1 < emaBuffer[1] && rsiValue < InpRSIMid);
   }
   else if(InpFilterMode == "EMA + Structure")
   {
      bool bullStruct, bearStruct;
      CheckMarketStructure(structShort, structLong, bullStruct, bearStruct);
      buyFilterOK = (close1 > emaBuffer[1] && bullStruct);
      sellFilterOK = (close1 < emaBuffer[1] && bearStruct);
   }
   
   // Apply filter mode to signals (matching Pine: applied to orange signals before combining)
   buyOrangeInZone = buyOrangeInZone && buyFilterOK;
   sellOrangeInZone = sellOrangeInZone && sellFilterOK;
   
   // Recalculate raw signals after filter mode applied to orange
   rawBullSignal = bullEngulf || bullConsec || buyOrangeInZone;
   rawBearSignal = bearEngulf || bearConsec || sellOrangeInZone;
   
   // Recalculate selected signals
   if(rawBullSignal)
   {
      if(hasEngulfingBull)
         selectedBullSignal = true;
      else if(buyOrangeInZone)
         selectedBullSignal = true;
   }
   
   if(rawBearSignal)
   {
      if(hasEngulfingBear)
         selectedBearSignal = true;
      else if(sellOrangeInZone)
         selectedBearSignal = true;
   }
   
   // Recalculate filtered signals
   baseBullOK = selectedBullSignal && qualityBullOK && spacingBullOK;
   baseBearOK = selectedBearSignal && qualityBearOK && spacingBearOK;
   filteredBullSignal = baseBullOK;
   filteredBearSignal = baseBearOK;
   
   // BLOCKERS (Quality Filters) - Full Pine Script Implementation
   bool buyBlockersOK = true;
   bool sellBlockersOK = true;
   double emaSlopeAbsATR_blocker = 0.0;  // For diagnostics
   
   if(InpEnableBlockers)
   {
      // Space blocker
      double atrSpace = atrBuffer[1];
      double buySpace = 0, sellSpace = 0;
      
      // Find nearest supply/demand zones for space calculation
      double nearestSupplyTop = 0;
      double nearestDemandBottom = 0;
      
      for(int z = 0; z < ArraySize(supplyTopPrices); z++)
      {
         if(supplyTopPrices[z] > close1 && (nearestSupplyTop == 0 || supplyTopPrices[z] < nearestSupplyTop))
            nearestSupplyTop = supplyTopPrices[z];
      }
      
      for(int z = 0; z < ArraySize(demandBottomPrices); z++)
      {
         if(demandBottomPrices[z] < close1 && (nearestDemandBottom == 0 || demandBottomPrices[z] > nearestDemandBottom))
            nearestDemandBottom = demandBottomPrices[z];
      }
      
      if(nearestSupplyTop > 0)
         buySpace = nearestSupplyTop - close1;
      else
      {
         // Use structure high
         double recentHigh = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, InpStructLookback, 1));
         buySpace = recentHigh - close1;
      }
      
      if(nearestDemandBottom > 0)
         sellSpace = close1 - nearestDemandBottom;
      else
      {
         // Use structure low
         double recentLow = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, InpStructLookback, 1));
         sellSpace = close1 - recentLow;
      }
      
      bool spaceOK_buy = (buySpace <= 0 || buySpace >= InpMinSpaceATR * atrSpace);
      bool spaceOK_sell = (sellSpace <= 0 || sellSpace >= InpMinSpaceATR * atrSpace);
      
      // EMA Slope blocker
      double emaBlockBuffer[];
      ArraySetAsSeries(emaBlockBuffer, true);
      int emaBlockHandle = iMA(_Symbol, _Period, InpEMASlopeLen, 0, MODE_EMA, PRICE_CLOSE);
      bool emaSlopeOK_buy = true;  // Default: do not block if slope calc fails
      bool emaSlopeOK_sell = true;
      
      int emaBlockBufferCopied = 0;
      if(emaBlockHandle != INVALID_HANDLE)
         emaBlockBufferCopied = CopyBuffer(emaBlockHandle, 0, 0, 3, emaBlockBuffer);
      
      if(emaBlockHandle != INVALID_HANDLE && emaBlockBufferCopied >= 3)
      {
         // Use closed bars: buffer[1] = current closed bar, buffer[2] = previous closed bar
         double emaBlock = emaBlockBuffer[1];      // Current closed bar
         double emaBlockPrev = emaBlockBuffer[2];   // Previous closed bar
         double emaSlope = emaBlock - emaBlockPrev; // Slope = current - previous
         
         // Normalize by ATR and guard against division by zero
         if(atrSpace > 0 && MathIsValidNumber(atrSpace))
         {
            emaSlopeAbsATR_blocker = MathAbs(emaSlope) / atrSpace;
            emaSlopeOK_buy = (emaSlope >= InpMinEmaSlopeATR * atrSpace && close1 > emaBlock);
            emaSlopeOK_sell = (emaSlope <= -InpMinEmaSlopeATR * atrSpace && close1 < emaBlock);
         }
         else
         {
            // ATR invalid - do not block trades
            emaSlopeOK_buy = true;
            emaSlopeOK_sell = true;
            if(InpVerboseLogs)
               Print("WARNING: Invalid ATR for EMA slope blocker, allowing trades");
         }
      }
      else
      {
         // CopyBuffer failed or insufficient - do not block trades
         if(InpVerboseLogs)
         {
            if(emaBlockHandle == INVALID_HANDLE)
               Print("WARNING: Failed to create EMA block handle, allowing trades");
            else
               Print("WARNING: Failed to copy EMA block buffer (got ", emaBlockBufferCopied, " values, need 3), allowing trades");
         }
      }
      
      // Structure blocker
      bool bullStruct, bearStruct;
      CheckMarketStructure(InpStructLookback, InpStructLookback * 2, bullStruct, bearStruct);
      bool structureOK_buy = bullStruct;
      bool structureOK_sell = bearStruct;
      
      // Impulse blocker
      double impHigh = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, InpImpulseRangeLookback, 1));
      double impLow = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, InpImpulseRangeLookback, 1));
      double impRange = impHigh - impLow;
      double impulsePos = (impRange > 0) ? (close1 - impLow) / impRange : 0.5;
      
      bool impulseOK_buy = true;
      bool impulseOK_sell = true;
      if(impRange > atrSpace)
      {
         impulseOK_buy = (impulsePos <= InpMaxEntryPctIntoImpulse + 0.15);
         impulseOK_sell = (impulsePos >= (1.0 - InpMaxEntryPctIntoImpulse - 0.15));
      }
      
      buyBlockersOK = (!InpUseSpaceBlocker || spaceOK_buy) &&
                     (!InpUseSlopeBlocker || emaSlopeOK_buy) &&
                     (!InpUseStructureBlocker || structureOK_buy) &&
                     (!InpUseImpulseBlocker || impulseOK_buy);
      
      sellBlockersOK = (!InpUseSpaceBlocker || spaceOK_sell) &&
                      (!InpUseSlopeBlocker || emaSlopeOK_sell) &&
                      (!InpUseStructureBlocker || structureOK_sell) &&
                      (!InpUseImpulseBlocker || impulseOK_sell);
      
      IndicatorRelease(emaBlockHandle);
   }
   
   // CONTEXT BLOCKERS - Full Pine Script Implementation
   bool buyContextOK = true;
   bool sellContextOK = true;
   double emaSlopeAbsATR = 0.0;  // For diagnostics
   
   // Debug tracking for context blockers (only on new bar)
   string contextDebugBuy = "";
   string contextDebugSell = "";
   bool proximityFailOpen = false;  // Track if proximity blocker failed-open
   
   if(InpEnableContextBlockers)
   {
      double atrContext = atrBuffer[1];
      double emaContext = emaBuffer[1];
      
      // EMA Slope Context Blocker
      double emaSlopeContext = 0;
      bool emaSlopeOKContext = true;
      
      if(InpUseEMASlopeBlockerContext)
      {
         // Ensure we have enough buffer values (require >= 3 for buffer[2] access)
         if(emaBufferOK && MathIsValidNumber(emaBuffer[1]) && MathIsValidNumber(emaBuffer[2]))
         {
            // Use closed bars: buffer[1] = current closed bar, buffer[2] = previous closed bar
            double emaContextCurrent = emaBuffer[1];  // Current closed bar
            double emaContextPrev = emaBuffer[2];    // Previous closed bar
            emaSlopeContext = emaContextCurrent - emaContextPrev;
            
            // Normalize by ATR and guard against division by zero
            if(atrContext > 0 && MathIsValidNumber(atrContext))
            {
               emaSlopeAbsATR = MathAbs(emaSlopeContext) / atrContext;
               emaSlopeOKContext = (emaSlopeAbsATR >= Context_EMA_SlopeMin_ATR);
               if(!emaSlopeOKContext)
               {
                  contextDebugBuy += "emaSlope(" + DoubleToString(emaSlopeAbsATR, 4) + "<" + DoubleToString(Context_EMA_SlopeMin_ATR, 4) + ") ";
                  contextDebugSell += "emaSlope(" + DoubleToString(emaSlopeAbsATR, 4) + "<" + DoubleToString(Context_EMA_SlopeMin_ATR, 4) + ") ";
               }
            }
            else
            {
               // ATR invalid - fail-open: do not block trades
               emaSlopeOKContext = true;
               if(InpVerboseLogs)
                  Print("WARNING: Invalid ATR for EMA slope context blocker, allowing trades (fail-open)");
            }
         }
         else
         {
            // Buffer insufficient - fail-open: do not block trades
            emaSlopeOKContext = true;
            if(InpVerboseLogs && !emaBufferOK)
               Print("WARNING: EMA buffer insufficient for slope context blocker (got ", emaBufferCopied, " values, need 3), allowing trades (fail-open)");
         }
      }
      
      // ATR Body Blocker
      double bodySize = MathAbs(close1 - open1);
      double bodyATR = 0.0;
      bool bodyOK = true;
      if(InpUseATRBodyBlocker)
      {
         if(atrContext > 0 && MathIsValidNumber(atrContext))
         {
            bodyATR = bodySize / atrContext;
            bodyOK = (bodyATR >= InpMinBodyATR);
            if(!bodyOK)
            {
               contextDebugBuy += "bodyATR(" + DoubleToString(bodyATR, 4) + "<" + DoubleToString(InpMinBodyATR, 4) + ") ";
               contextDebugSell += "bodyATR(" + DoubleToString(bodyATR, 4) + "<" + DoubleToString(InpMinBodyATR, 4) + ") ";
            }
         }
         else
         {
            // ATR invalid - fail-open: do not block trades
            bodyOK = true;
         }
      }
      
      // Late Entry Blocker
      int bullishCount = 0, bearishCount = 0;
      bool lateEntryOK_buy = true;
      bool lateEntryOK_sell = true;
      if(InpUseLateEntryBlocker)
      {
         for(int i = 1; i <= InpLateEntryLookback; i++)
         {
            double o = iOpen(_Symbol, _Period, i + 1);
            double c = iClose(_Symbol, _Period, i + 1);
            if(c > o) bullishCount++;
            if(c < o) bearishCount++;
         }
         lateEntryOK_buy = (bullishCount <= InpMaxSameColorBeforeEntry);
         lateEntryOK_sell = (bearishCount <= InpMaxSameColorBeforeEntry);
         if(!lateEntryOK_buy)
            contextDebugBuy += "lateEntry(bullish=" + IntegerToString(bullishCount) + ">" + IntegerToString(InpMaxSameColorBeforeEntry) + ") ";
         if(!lateEntryOK_sell)
            contextDebugSell += "lateEntry(bearish=" + IntegerToString(bearishCount) + ">" + IntegerToString(InpMaxSameColorBeforeEntry) + ") ";
      }
      
      // Proximity to EMA
      double distToEMA = 0.0;
      bool proximityOK = true;
      if(InpUseProximityToEMA)
      {
         if(atrContext > 0 && MathIsValidNumber(atrContext))
         {
            distToEMA = MathAbs(close1 - emaContext) / atrContext;
            proximityOK = (distToEMA <= InpEMAProxATR);
            
            // Fail-open if threshold seems misconfigured (distance >> threshold suggests threshold too strict)
            if(!proximityOK && distToEMA > 3.0 && InpEMAProxATR < 1.0)
            {
               // Threshold appears too strict - fail-open to prevent permanent blocking
               proximityOK = true;
               proximityFailOpen = true;  // Track for diagnostic output
            }
            else if(!proximityOK)
            {
               contextDebugBuy += "proximity(" + DoubleToString(distToEMA, 4) + ">" + DoubleToString(InpEMAProxATR, 4) + ") ";
               contextDebugSell += "proximity(" + DoubleToString(distToEMA, 4) + ">" + DoubleToString(InpEMAProxATR, 4) + ") ";
            }
         }
         else
         {
            // ATR invalid - fail-open: do not block trades
            proximityOK = true;
         }
      }
      
      // Recent Breakout Confirm
      bool breakoutOK_buy = true;
      bool breakoutOK_sell = true;
      if(InpUseRecentBreakoutConfirm)
      {
         if(atrContext > 0 && MathIsValidNumber(atrContext))
         {
            double prevHigh = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, InpBreakoutLookback, 2));
            double prevLow = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, InpBreakoutLookback, 2));
            breakoutOK_buy = (close1 > prevHigh || (close1 - emaContext) >= InpBreakoutATR * atrContext);
            breakoutOK_sell = (close1 < prevLow || (emaContext - close1) >= InpBreakoutATR * atrContext);
            if(!breakoutOK_buy)
               contextDebugBuy += "breakout ";
            if(!breakoutOK_sell)
               contextDebugSell += "breakout ";
         }
         else
         {
            // ATR invalid - fail-open: do not block trades
            breakoutOK_buy = true;
            breakoutOK_sell = true;
         }
      }
      
      buyContextOK = (!InpUseEMASlopeBlockerContext || emaSlopeOKContext) &&
                    bodyOK &&
                    lateEntryOK_buy &&
                    proximityOK &&
                    (!InpUseRecentBreakoutConfirm || breakoutOK_buy);
      
      sellContextOK = (!InpUseEMASlopeBlockerContext || emaSlopeOKContext) &&
                     bodyOK &&
                     lateEntryOK_sell &&
                     proximityOK &&
                     (!InpUseRecentBreakoutConfirm || breakoutOK_sell);
   }
   
   // Final signals (matching plotBuy/plotSell)
   bool plotBuy = filteredBullSignal && buyBlockersOK && buyContextOK;
   bool plotSell = filteredBearSignal && sellBlockersOK && sellContextOK;
   
   // Diagnostics (only on new bar, only if verbose logs enabled)
   if(InpVerboseLogs)
   {
      datetime bar1Time = iTime(_Symbol, _Period, 1);
      double spreadPoints = GetSpreadPoints();
      
      // Print diagnostic summary
      string diag = StringFormat("BAR[1]=%s | plotBuy=%s plotSell=%s | filteredBull=%s filteredBear=%s | ",
                                 TimeToString(bar1Time, TIME_DATE|TIME_MINUTES),
                                 (plotBuy ? "YES" : "NO"), (plotSell ? "YES" : "NO"),
                                 (filteredBullSignal ? "YES" : "NO"), (filteredBearSignal ? "YES" : "NO"));
      
      diag += StringFormat("buyBlockersOK=%s sellBlockersOK=%s | buyContextOK=%s sellContextOK=%s | ",
                           (buyBlockersOK ? "YES" : "NO"), (sellBlockersOK ? "YES" : "NO"),
                           (buyContextOK ? "YES" : "NO"), (sellContextOK ? "YES" : "NO"));
      
      diag += StringFormat("emaSlopeATR_blocker=%.4f emaSlopeATR_context=%.4f | spread=%.1fpts",
                           emaSlopeAbsATR_blocker, emaSlopeAbsATR, spreadPoints);
      
      if(proximityFailOpen)
         diag += " | proximityFailOpen=YES";
      
      Print(diag);
      
      // Print which gate failed if signal is false
      if(!plotBuy && filteredBullSignal)
      {
         if(!buyBlockersOK)
            Print("  BUY blocked by: buyBlockersOK=false");
         if(!buyContextOK)
         {
            Print("  BUY blocked by: buyContextOK=false");
            if(StringLen(contextDebugBuy) > 0)
               Print("    Context sub-gates failed: ", contextDebugBuy);
         }
      }
      if(!plotSell && filteredBearSignal)
      {
         if(!sellBlockersOK)
            Print("  SELL blocked by: sellBlockersOK=false");
         if(!sellContextOK)
         {
            Print("  SELL blocked by: sellContextOK=false");
            if(StringLen(contextDebugSell) > 0)
               Print("    Context sub-gates failed: ", contextDebugSell);
         }
      }
   }
   
   // Ignore new signals while PSV is waiting (optional)
   if(UsePostSignalValidator && PSV_IgnoreNewSignalsWhileWaiting && (psv_state == PSV_WAIT_BUY || psv_state == PSV_WAIT_SELL))
   {
      if((plotBuy || plotSell) && PSV_EnableLogs)
         Print("PSV IGNORE: new signal ignored while waiting");
      plotBuy = false;
      plotSell = false;
   }

   // Execute trades or store pending confirmation
   if(plotBuy && InpConfirmOnClose)
   {
      lastDetectedSignalBarIndex = currentBarIndex;
      if(UsePostSignalValidator)
      {
         // Post-Signal Validator: set WAIT state instead of executing
         // Cancel opposite direction
         if(psv_state == PSV_WAIT_SELL)
         {
            psv_state = PSV_IDLE;
            psv_signal_bar_time = 0;
            psv_waited = 0;
            psv_pending_hold_check = false;
            if(PSV_EnableLogs)
               Print("PSV CANCEL reason=new BUY signal cancels pending SELL");
         }
         
         // Set WAIT_BUY state
         datetime bar1Time = iTime(_Symbol, _Period, 1);
         psv_state = PSV_WAIT_BUY;
         psv_signal_bar_time = bar1Time;
         psv_waited = 0;
         psv_dir = 1;
         psv_pending_hold_check = false;
         
         if(PSV_EnableLogs)
            Print("PSV WAIT BUY");
      }
      else if(UseCandleValidation)
      {
         // Candle validation layer: set WAIT state instead of executing
         // Cancel opposite direction
         if(currentState == SIGNAL_WAIT_SELL)
         {
            currentState = SIGNAL_IDLE;
            signalBarTime = 0;
            barsWaited = 0;
            if(InpVerboseLogs)
               Print("CANCEL: New BUY signal cancels pending SELL validation");
         }
         
         // Set WAIT_BUY state
         datetime bar1Time = iTime(_Symbol, _Period, 1);
         currentState = SIGNAL_WAIT_BUY;
         signalBarTime = bar1Time;
         barsWaited = 0;
         
         if(InpVerboseLogs)
            Print("WAIT_BUY: Signal detected at bar time ", TimeToString(bar1Time, TIME_DATE|TIME_MINUTES), ", waiting for candle confirmation");
      }
      else if(UseConfirmationEntry)
      {
         // Cancel existing pending if opposite direction
         if(pendingConfirm.active && pendingConfirm.direction == -1)
         {
            pendingConfirm.active = false;
            if(InpVerboseLogs)
               Print("CONFIRM_CANCELLED: New BUY signal cancels pending SELL confirmation");
         }
         
         // Store pending confirmation instead of executing immediately
         int bars = Bars(_Symbol, _Period);
         datetime bar1Time = iTime(_Symbol, _Period, 1);
         double high1 = iHigh(_Symbol, _Period, 1);
         double low1 = iLow(_Symbol, _Period, 1);
         
         pendingConfirm.active = true;
         pendingConfirm.direction = 1;  // Buy
         pendingConfirm.signalBarTime = bar1Time;
         pendingConfirm.signalHigh = high1;
         pendingConfirm.signalLow = low1;
         pendingConfirm.barsLeft = ConfirmExpireBars + 1;  // +1 to account for immediate decrement on creation bar
         pendingConfirm.signalBarIndex = bars - 1;
         
         if(InpVerboseLogs)
            Print("CONFIRM_PENDING: BUY at bar time ", TimeToString(bar1Time, TIME_DATE|TIME_MINUTES), 
                  ", breakout above ", DoubleToString(high1, _Digits), ", expires in ", ConfirmExpireBars, " bars");
      }
      else
      {
         ExecuteBuySignal();
      }
   }
   else if(plotSell && InpConfirmOnClose)
   {
      lastDetectedSignalBarIndex = currentBarIndex;
      if(UsePostSignalValidator)
      {
         // Post-Signal Validator: set WAIT state instead of executing
         // Cancel opposite direction
         if(psv_state == PSV_WAIT_BUY)
         {
            psv_state = PSV_IDLE;
            psv_signal_bar_time = 0;
            psv_waited = 0;
            psv_pending_hold_check = false;
            if(PSV_EnableLogs)
               Print("PSV CANCEL reason=new SELL signal cancels pending BUY");
         }
         
         // Set WAIT_SELL state
         datetime bar1Time = iTime(_Symbol, _Period, 1);
         psv_state = PSV_WAIT_SELL;
         psv_signal_bar_time = bar1Time;
         psv_waited = 0;
         psv_dir = -1;
         psv_pending_hold_check = false;
         
         if(PSV_EnableLogs)
            Print("PSV WAIT SELL");
      }
      else if(UseCandleValidation)
      {
         // Candle validation layer: set WAIT state instead of executing
         // Cancel opposite direction
         if(currentState == SIGNAL_WAIT_BUY)
         {
            currentState = SIGNAL_IDLE;
            signalBarTime = 0;
            barsWaited = 0;
            if(InpVerboseLogs)
               Print("CANCEL: New SELL signal cancels pending BUY validation");
         }
         
         // Set WAIT_SELL state
         datetime bar1Time = iTime(_Symbol, _Period, 1);
         currentState = SIGNAL_WAIT_SELL;
         signalBarTime = bar1Time;
         barsWaited = 0;
         
         if(InpVerboseLogs)
            Print("WAIT_SELL: Signal detected at bar time ", TimeToString(bar1Time, TIME_DATE|TIME_MINUTES), ", waiting for candle confirmation");
      }
      else if(UseConfirmationEntry)
      {
         // Cancel existing pending if opposite direction
         if(pendingConfirm.active && pendingConfirm.direction == 1)
         {
            pendingConfirm.active = false;
            if(InpVerboseLogs)
               Print("CONFIRM_CANCELLED: New SELL signal cancels pending BUY confirmation");
         }
         
         // Store pending confirmation instead of executing immediately
         int bars = Bars(_Symbol, _Period);
         datetime bar1Time = iTime(_Symbol, _Period, 1);
         double high1 = iHigh(_Symbol, _Period, 1);
         double low1 = iLow(_Symbol, _Period, 1);
         
         pendingConfirm.active = true;
         pendingConfirm.direction = -1;  // Sell
         pendingConfirm.signalBarTime = bar1Time;
         pendingConfirm.signalHigh = high1;
         pendingConfirm.signalLow = low1;
         pendingConfirm.barsLeft = ConfirmExpireBars + 1;  // +1 to account for immediate decrement on creation bar
         pendingConfirm.signalBarIndex = bars - 1;
         
         if(InpVerboseLogs)
            Print("CONFIRM_PENDING: SELL at bar time ", TimeToString(bar1Time, TIME_DATE|TIME_MINUTES), 
                  ", breakout below ", DoubleToString(low1, _Digits), ", expires in ", ConfirmExpireBars, " bars");
      }
      else
      {
         ExecuteSellSignal();
      }
   }
}

//+------------------------------------------------------------------+
//| Check confirmation entry triggers                                |
//+------------------------------------------------------------------+
void CheckConfirmationEntry(bool isNewBar)
{
   if(!pendingConfirm.active)
      return;
   
   // Handle expiry on new bar
   if(isNewBar)
   {
      pendingConfirm.barsLeft--;
      if(pendingConfirm.barsLeft <= 0)
      {
         pendingConfirm.active = false;
         if(InpVerboseLogs)
            Print("CONFIRM_EXPIRED: ", (pendingConfirm.direction == 1 ? "BUY" : "SELL"), 
                  " pending signal expired");
         return;
      }
   }
   
   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point <= 0)
      return;
   
   // Get ATR for buffer calculation
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return;
   double atr = atrBuffer[0];
   
   // Calculate buffer in points
   double atrPoints = atr / point;
   double spreadPoints = GetSpreadPoints();
   double bufPoints = MathMax(ConfirmBuffer_ATR * atrPoints, ConfirmBuffer_SpreadFactor * spreadPoints);
   
   // Check trigger conditions
   bool triggered = false;
   
   if(pendingConfirm.direction == 1)  // BUY: Ask >= signalHigh + buffer
   {
      double triggerLevel = pendingConfirm.signalHigh + bufPoints * point;
      if(ask >= triggerLevel)
         triggered = true;
   }
   else  // SELL: Bid <= signalLow - buffer
   {
      double triggerLevel = pendingConfirm.signalLow - bufPoints * point;
      if(bid <= triggerLevel)
         triggered = true;
   }
   
   if(triggered)
   {
      pendingConfirm.active = false;
      
      if(InpVerboseLogs)
         Print("CONFIRM_TRIGGERED: ", (pendingConfirm.direction == 1 ? "BUY" : "SELL"), 
               " breakout hit, placing batch now");
      
      // Execute the signal (all existing safety checks will apply)
      if(pendingConfirm.direction == 1)
         ExecuteBuySignal();
      else
         ExecuteSellSignal();
   }
}

//+------------------------------------------------------------------+
//| Execute buy signal                                               |
//+------------------------------------------------------------------+
void ExecuteBuySignal()
{
   // Check filters
   if(!IsSpreadOK())
   {
      if(InpVerboseLogs)
         Print("BUY signal blocked: Spread too wide");
      return;
   }
   
   if(!IsGapOK())
   {
      if(InpVerboseLogs)
         Print("BUY signal blocked: Gap too large");
      return;
   }
   
   // Check max trades
   int currentTrades = CountPositionsByMagicSymbol(MagicNumber, _Symbol);
   if(currentTrades >= Max_Open_Trades)
   {
      if(InpVerboseLogs)
         Print("BUY signal blocked: Max trades reached (", currentTrades, ")");
      return;
   }
   
   // Get prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Get ATR for SL
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return;
   double atr = atrBuffer[0];
   
   // Calculate SL (ATR or Swing modes)
   double atrVal = atr; // already computed above
   double spreadPoints = GetSpreadPoints();
   
   double atrSLDistance = MathMax(atrVal * Stop_Loss_Multiplier, Minimum_Stop_Loss_Points * point);
   double slPrice = ask - atrSLDistance; // default ATR behavior
   
   if(InpSLMode == SL_SWING || InpSLMode == SL_SWING_PLUS_ATR)
   {
      double swingLow = GetSwingLow(Swing_Lookback_Bars, Swing_Use_Shift);
      
      // Base swing SL (below swing low)
      double swingPadATR = (atrVal > 0 ? atrVal * Swing_ATR_Padding_Mult : 0.0);
      double swingPadSpread = spreadPoints * Swing_Spread_Padding_Factor * point;
      double swingPad = MathMax(swingPadATR, swingPadSpread);
      
      double candidateSL = swingLow - swingPad;
      
      if(InpSLMode == SL_SWING_PLUS_ATR)
      {
         // Ensure at least ATR-distance too (avoid too-tight swing in noisy markets)
         double atrFloorSL = ask - atrSLDistance;
         // For BUY, we want the LOWER (wider) SL to avoid stop-hunts
         candidateSL = MathMin(candidateSL, atrFloorSL);
      }
      
      // Safety: SL must be below entry for BUY and valid
      if(candidateSL < ask - (point * 2))
         slPrice = candidateSL;
      // else keep default ATR slPrice
   }
   
   // Calculate TPs using R-multiples
   double risk = ask - slPrice;
   double tp1Price = ask + risk * Take_Profit_1_Multiplier;
   double tp2Price = ask + risk * Take_Profit_2_Multiplier;
   double tp3Price = ask + risk * Take_Profit_3_Multiplier;  // TP3 uses runner distance
   
   // Calculate lot sizes with redistribution to ensure all legs meet minimum
   double lot1 = 0, lot2 = 0, lot3 = 0;
   bool redistributed = false;
   bool useFallback = !RedistributeLots(lot1, lot2, lot3, Position_Size, 
                                         TP1_Percent, TP2_Percent, TP3_Percent, redistributed);
   
   // If fallback is needed (only TP3), ensure it's valid
   if(useFallback && lot3 <= 0)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      lot3 = NormalizeLot(minLot);
      if(InpVerboseLogs)
         Print("LOT FALLBACK: Using minimum lot for TP3: ", lot3);
   }
   
   // Get invalidation level
   double buyPx = (InpZoneTouchMode == "Close") ? iClose(_Symbol, _Period, 1) : iLow(_Symbol, _Period, 1);
   double invalidateLevel = GetTouchedDemandBottom(buyPx);
   if(invalidateLevel <= 0)
      invalidateLevel = iLow(_Symbol, _Period, 1);
   
   // Set trade context
   SetTradeContext();
   
   // Place all 3 orders (all-or-nothing)
   // Comments include invalidation level for reconstruction after restart
   ulong ticket1 = 0, ticket2 = 0, ticket3 = 0;
   bool allOK = true;
   string comment1 = EncodeCommentWithInvLevel(nextBatchId, "TP1", ask, invalidateLevel);
   string comment2 = EncodeCommentWithInvLevel(nextBatchId, "TP2", ask, invalidateLevel);
   string comment3 = EncodeCommentWithInvLevel(nextBatchId, "TP3", ask, invalidateLevel);
   
   // Place TP1
   if(lot1 > 0)
   {
      if(!trade.Buy(lot1, _Symbol, ask, slPrice, tp1Price, comment1))
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to place TP1 order. Error: ", GetLastError());
         allOK = false;
      }
      else
      {
         // Wait a moment for order to execute, then find position ticket
         Sleep(100);
         ticket1 = FindPositionTicketByComment(comment1);
         if(ticket1 == 0)
         {
            if(InpVerboseLogs)
               Print("WARNING: TP1 order placed but position not found by comment: ", comment1);
            allOK = false;
         }
      }
   }
   
   // Place TP2
   if(allOK && lot2 > 0)
   {
      if(!trade.Buy(lot2, _Symbol, ask, slPrice, tp2Price, comment2))
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to place TP2 order. Error: ", GetLastError());
         allOK = false;
         // Close TP1 if TP2 fails (use comment to find position) - only if TP1 was placed
         if(lot1 > 0 && !ClosePositionByComment(comment1))
         {
            if(InpVerboseLogs)
               Print("WARNING: Failed to close TP1 position after TP2 failure");
         }
      }
      else
      {
         // Wait a moment for order to execute, then find position ticket
         Sleep(100);
         ticket2 = FindPositionTicketByComment(comment2);
         if(ticket2 == 0)
         {
            if(InpVerboseLogs)
               Print("WARNING: TP2 order placed but position not found by comment: ", comment2);
            allOK = false;
            // Close TP1 if TP2 position not found
            ClosePositionByComment(comment1);
         }
      }
   }
   
   // Place TP3
   if(allOK && lot3 > 0)
   {
      if(!trade.Buy(lot3, _Symbol, ask, slPrice, tp3Price, comment3))
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to place TP3 order. Error: ", GetLastError());
         allOK = false;
         // Close TP1 and TP2 if TP3 fails (use comments to find positions) - only if they were placed
         if(lot1 > 0) ClosePositionByComment(comment1);
         if(lot2 > 0) ClosePositionByComment(comment2);
      }
      else
      {
         // Wait a moment for order to execute, then find position ticket
         Sleep(100);
         ticket3 = FindPositionTicketByComment(comment3);
         if(ticket3 == 0)
         {
            if(InpVerboseLogs)
               Print("WARNING: TP3 order placed but position not found by comment: ", comment3);
            allOK = false;
            // Close TP1 and TP2 if TP3 position not found - only if they were placed
            if(lot1 > 0) ClosePositionByComment(comment1);
            if(lot2 > 0) ClosePositionByComment(comment2);
         }
      }
   }
   
   // If all orders placed successfully and positions found, create batch
   if(allOK && (ticket1 > 0 || ticket2 > 0 || ticket3 > 0))
   {
      BatchInfo batch;
      batch.signalTime = iTime(_Symbol, _Period, 0);
      batch.direction = 1;
      batch.entryPrice = ask;
      batch.tp1 = tp1Price;
      batch.tp2 = tp2Price;
      batch.tp3 = tp3Price;
      batch.slInitial = slPrice;
      batch.invalidateLevel = invalidateLevel;
      batch.invalidateExpiry = batch.signalTime + Invalidation_Window_Bars * PeriodSeconds(_Period);
      batch.ticket1 = ticket1;
      batch.ticket2 = ticket2;
      batch.ticket3 = ticket3;
      batch.movedToBE = false;
      batch.movedToTP2 = false;
      batch.invalidationTriggered = false;
      batch.batchId = nextBatchId++;
      
      int size = ArraySize(batches);
      ArrayResize(batches, size + 1);
      batches[size] = batch;
      
      lastSignalBarIndex = Bars(_Symbol, _Period) - 1;
      lastSignalDirection = 1;
      
      if(InpVerboseLogs)
         Print("BUY signal executed. Batch ID: ", batch.batchId, " Entry: ", ask, " SL: ", slPrice, " TP1: ", tp1Price, " TP2: ", tp2Price, " TP3: ", tp3Price);
   }
}

//+------------------------------------------------------------------+
//| Execute sell signal                                              |
//+------------------------------------------------------------------+
void ExecuteSellSignal()
{
   // Check filters
   if(!IsSpreadOK())
   {
      if(InpVerboseLogs)
         Print("SELL signal blocked: Spread too wide");
      return;
   }
   
   if(!IsGapOK())
   {
      if(InpVerboseLogs)
         Print("SELL signal blocked: Gap too large");
      return;
   }
   
   // Check max trades
   int currentTrades = CountPositionsByMagicSymbol(MagicNumber, _Symbol);
   if(currentTrades >= Max_Open_Trades)
   {
      if(InpVerboseLogs)
         Print("SELL signal blocked: Max trades reached (", currentTrades, ")");
      return;
   }
   
   // Get prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Get ATR for SL
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return;
   double atr = atrBuffer[0];
   
   // Calculate SL (ATR or Swing modes)
   double atrVal = atr; // already computed above
   double spreadPoints = GetSpreadPoints();
   
   double atrSLDistance = MathMax(atrVal * Stop_Loss_Multiplier, Minimum_Stop_Loss_Points * point);
   double slPrice = bid + atrSLDistance; // default ATR behavior
   
   if(InpSLMode == SL_SWING || InpSLMode == SL_SWING_PLUS_ATR)
   {
      double swingHigh = GetSwingHigh(Swing_Lookback_Bars, Swing_Use_Shift);
      
      // Base swing SL (above swing high)
      double swingPadATR = (atrVal > 0 ? atrVal * Swing_ATR_Padding_Mult : 0.0);
      double swingPadSpread = spreadPoints * Swing_Spread_Padding_Factor * point;
      double swingPad = MathMax(swingPadATR, swingPadSpread);
      
      double candidateSL = swingHigh + swingPad;
      
      if(InpSLMode == SL_SWING_PLUS_ATR)
      {
         // Ensure at least ATR-distance too
         double atrFloorSL = bid + atrSLDistance;
         // For SELL, we want the HIGHER (wider) SL to avoid stop-hunts
         candidateSL = MathMax(candidateSL, atrFloorSL);
      }
      
      // Safety: SL must be above entry for SELL and valid
      if(candidateSL > bid + (point * 2))
         slPrice = candidateSL;
      // else keep default ATR slPrice
   }

   // Calculate TPs using R-multiples
   double risk = slPrice - bid;
   double tp1Price = bid - risk * Take_Profit_1_Multiplier;
   double tp2Price = bid - risk * Take_Profit_2_Multiplier;
   double tp3Price = bid - risk * Take_Profit_3_Multiplier;  // TP3 uses runner distance
   
   // Calculate lot sizes with redistribution to ensure all legs meet minimum
   double lot1 = 0, lot2 = 0, lot3 = 0;
   bool redistributed = false;
   bool useFallback = !RedistributeLots(lot1, lot2, lot3, Position_Size, 
                                         TP1_Percent, TP2_Percent, TP3_Percent, redistributed);
   
   // If fallback is needed (only TP3), ensure it's valid
   if(useFallback && lot3 <= 0)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      lot3 = NormalizeLot(minLot);
      if(InpVerboseLogs)
         Print("LOT FALLBACK: Using minimum lot for TP3: ", lot3);
   }
   
   // Get invalidation level
   double sellPx = (InpZoneTouchMode == "Close") ? iClose(_Symbol, _Period, 1) : iHigh(_Symbol, _Period, 1);
   double invalidateLevel = GetTouchedSupplyTop(sellPx);
   if(invalidateLevel <= 0)
      invalidateLevel = iHigh(_Symbol, _Period, 1);
   
   // Set trade context
   SetTradeContext();
   
   // Place all 3 orders (all-or-nothing)
   // Comments include invalidation level for reconstruction after restart
   ulong ticket1 = 0, ticket2 = 0, ticket3 = 0;
   bool allOK = true;
   string comment1 = EncodeCommentWithInvLevel(nextBatchId, "TP1", bid, invalidateLevel);
   string comment2 = EncodeCommentWithInvLevel(nextBatchId, "TP2", bid, invalidateLevel);
   string comment3 = EncodeCommentWithInvLevel(nextBatchId, "TP3", bid, invalidateLevel);
   
   // Place TP1
   if(lot1 > 0)
   {
      if(!trade.Sell(lot1, _Symbol, bid, slPrice, tp1Price, comment1))
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to place TP1 order. Error: ", GetLastError());
         allOK = false;
      }
      else
      {
         // Wait a moment for order to execute, then find position ticket
         Sleep(100);
         ticket1 = FindPositionTicketByComment(comment1);
         if(ticket1 == 0)
         {
            if(InpVerboseLogs)
               Print("WARNING: TP1 order placed but position not found by comment: ", comment1);
            allOK = false;
         }
      }
   }
   
   // Place TP2
   if(allOK && lot2 > 0)
   {
      if(!trade.Sell(lot2, _Symbol, bid, slPrice, tp2Price, comment2))
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to place TP2 order. Error: ", GetLastError());
         allOK = false;
         // Close TP1 if TP2 fails (use comment to find position) - only if TP1 was placed
         if(lot1 > 0 && !ClosePositionByComment(comment1))
         {
            if(InpVerboseLogs)
               Print("WARNING: Failed to close TP1 position after TP2 failure");
         }
      }
      else
      {
         // Wait a moment for order to execute, then find position ticket
         Sleep(100);
         ticket2 = FindPositionTicketByComment(comment2);
         if(ticket2 == 0)
         {
            if(InpVerboseLogs)
               Print("WARNING: TP2 order placed but position not found by comment: ", comment2);
            allOK = false;
            // Close TP1 if TP2 position not found - only if TP1 was placed
            if(lot1 > 0) ClosePositionByComment(comment1);
         }
      }
   }
   
   // Place TP3
   if(allOK && lot3 > 0)
   {
      if(!trade.Sell(lot3, _Symbol, bid, slPrice, tp3Price, comment3))
      {
         if(InpVerboseLogs)
            Print("ERROR: Failed to place TP3 order. Error: ", GetLastError());
         allOK = false;
         // Close TP1 and TP2 if TP3 fails (use comments to find positions) - only if they were placed
         if(lot1 > 0) ClosePositionByComment(comment1);
         if(lot2 > 0) ClosePositionByComment(comment2);
      }
      else
      {
         // Wait a moment for order to execute, then find position ticket
         Sleep(100);
         ticket3 = FindPositionTicketByComment(comment3);
         if(ticket3 == 0)
         {
            if(InpVerboseLogs)
               Print("WARNING: TP3 order placed but position not found by comment: ", comment3);
            allOK = false;
            // Close TP1 and TP2 if TP3 position not found - only if they were placed
            if(lot1 > 0) ClosePositionByComment(comment1);
            if(lot2 > 0) ClosePositionByComment(comment2);
         }
      }
   }
   
   // If all orders placed successfully and positions found, create batch
   if(allOK && (ticket1 > 0 || ticket2 > 0 || ticket3 > 0))
   {
      BatchInfo batch;
      batch.signalTime = iTime(_Symbol, _Period, 0);
      batch.direction = -1;
      batch.entryPrice = bid;
      batch.tp1 = tp1Price;
      batch.tp2 = tp2Price;
      batch.tp3 = tp3Price;
      batch.slInitial = slPrice;
      batch.invalidateLevel = invalidateLevel;
      batch.invalidateExpiry = batch.signalTime + Invalidation_Window_Bars * PeriodSeconds(_Period);
      batch.ticket1 = ticket1;
      batch.ticket2 = ticket2;
      batch.ticket3 = ticket3;
      batch.movedToBE = false;
      batch.movedToTP2 = false;
      batch.invalidationTriggered = false;
      batch.batchId = nextBatchId++;
      
      int size = ArraySize(batches);
      ArrayResize(batches, size + 1);
      batches[size] = batch;
      
      lastSignalBarIndex = Bars(_Symbol, _Period) - 1;
      lastSignalDirection = -1;
      
      if(InpVerboseLogs)
         Print("SELL signal executed. Batch ID: ", batch.batchId, " Entry: ", bid, " SL: ", slPrice, " TP1: ", tp1Price, " TP2: ", tp2Price, " TP3: ", tp3Price);
   }
}

//+------------------------------------------------------------------+
//| Helper: Check if TP3 SL modification would lock to TP2 (runner protection) |
//+------------------------------------------------------------------+
bool IsTP3RunnerProtectionBlocked(string comment, double newSL, double tp2Level, double tolerance)
{
   // Only protect TP3 positions
   if(StringFind(comment, "#TP3") < 0)
      return false;  // Not a TP3 position, allow modification
   
   // Check if newSL is close to TP2 level (within tolerance)
   double diff = MathAbs(newSL - tp2Level);
   if(diff <= tolerance)
   {
      Print("BLOCKED: Attempt to lock TP3 SL to TP2 (runner protection). Comment: ", comment, 
            " NewSL: ", newSL, " TP2: ", tp2Level, " Diff: ", diff);
      return true;  // Block the modification
   }
   
   return false;  // Allow modification
}

//+------------------------------------------------------------------+
//| Manage trades (breakeven, TP3 runner)                            |
//+------------------------------------------------------------------+
void ManageTrades()
{
   double spreadPoints = GetSpreadPoints();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 0; i < ArraySize(batches); i++)
   {
      // Check TP1 closed
      if(!batches[i].movedToBE)
      {
         bool tp1Closed = true;
         if(batches[i].ticket1 > 0)
         {
            string comment1 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP1";
            tp1Closed = !HasPositionByComment(comment1);
         }
         
         if(tp1Closed && (batches[i].ticket2 > 0 || batches[i].ticket3 > 0))
         {
            // Move TP2 and TP3 to breakeven
            // BE buffer accounts for spread to ensure profit after costs
            // BUY: SL triggered by Bid, so BE = entry + buffer (ensures profit when Bid hits)
            // SELL: SL triggered by Ask, so BE = entry - buffer (ensures profit when Ask hits)
            double beBuffer = MathMax(Breakeven_Buffer_Points * point, spreadPoints * Breakeven_Buffer_Multiplier * point);
            double newSL = batches[i].entryPrice;
            
            if(batches[i].direction == 1)  // Buy: BE above entry to ensure profit (SL triggered by Bid)
            {
               newSL = batches[i].entryPrice + beBuffer;
               // Safety: never move BUY SL down (must be >= initial SL)
               if(newSL < batches[i].slInitial)
                  newSL = batches[i].slInitial;
            }
            else  // Sell: BE below entry to ensure profit (SL triggered by Ask)
            {
               newSL = batches[i].entryPrice - beBuffer;
               // Safety: never move SELL SL up (must be <= initial SL)
               if(newSL > batches[i].slInitial)
                  newSL = batches[i].slInitial;
            }
            
            // Modify TP2 - find by comment (handles invalidation level suffix)
            string comment2 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP2";
            ulong ticket2 = 0;
            if(FindPositionTicketByComment(MagicNumber, _Symbol, comment2, ticket2))
            {
               if(positionInfo.SelectByTicket(ticket2))
               {
                  double currentSL = positionInfo.StopLoss();
                  // Safety: never worsen SL (BUY: newSL >= currentSL, SELL: newSL <= currentSL)
                  bool slOK = (batches[i].direction == 1) ? (newSL >= currentSL) : (newSL <= currentSL);
                  if(slOK)
                  {
                     if(trade.PositionModify(ticket2, newSL, batches[i].tp2))
                     {
                        batches[i].ticket2 = ticket2;
                        if(InpVerboseLogs)
                           Print("TP2 moved to breakeven. Batch: ", batches[i].batchId, " New SL: ", newSL, " Old SL: ", currentSL);
                     }
                     else if(InpVerboseLogs)
                     {
                        Print("ERROR: Failed to modify TP2 to breakeven. Batch: ", batches[i].batchId, " Error: ", GetLastError());
                     }
                  }
                  else if(InpVerboseLogs)
                  {
                     Print("WARNING: TP2 BE move blocked - would worsen SL. Batch: ", batches[i].batchId, " Current: ", currentSL, " Proposed: ", newSL);
                  }
               }
            }
            
            // Modify TP3 - find by comment (handles invalidation level suffix)
            string comment3 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP3";
            ulong ticket3 = 0;
            if(FindPositionTicketByComment(MagicNumber, _Symbol, comment3, ticket3))
            {
               if(positionInfo.SelectByTicket(ticket3))
               {
                  double currentSL = positionInfo.StopLoss();
                  // Safety: never worsen SL (BUY: newSL >= currentSL, SELL: newSL <= currentSL)
                  bool slOK = (batches[i].direction == 1) ? (newSL >= currentSL) : (newSL <= currentSL);
                  
                  // Runner protection: block TP3 SL from being locked to TP2 level
                  double tolerance = MathMax(point * 10, MathAbs(batches[i].tp2) * 0.001);  // 10 points or 0.1% of TP2, whichever is larger
                  if(IsTP3RunnerProtectionBlocked(comment3, newSL, batches[i].tp2, tolerance))
                  {
                     if(InpVerboseLogs)
                        Print("TP3 runner protection: Blocked SL modification to TP2 level. Batch: ", batches[i].batchId);
                     slOK = false;  // Block the modification
                  }
                  
                  if(slOK)
                  {
                     if(Move_TP3_To_BE_After_TP1)
                     {
                        if(trade.PositionModify(ticket3, newSL, batches[i].tp3))
                        {
                           batches[i].ticket3 = ticket3;
                           if(InpVerboseLogs)
                              Print("TP3 moved to breakeven. Batch: ", batches[i].batchId, " New SL: ", newSL, " Old SL: ", currentSL);
                        }
                        else if(InpVerboseLogs)
                        {
                           Print("ERROR: Failed to modify TP3 to breakeven. Batch: ", batches[i].batchId, " Error: ", GetLastError());
                        }
                     }
                     else
                     {
                        if(InpVerboseLogs)
                           Print("TP3 runner: BE move skipped after TP1 (runner breathing room). Batch: ", batches[i].batchId);
                     }
                  }
                  else if(InpVerboseLogs)
                  {
                     Print("WARNING: TP3 BE move blocked - would worsen SL. Batch: ", batches[i].batchId, " Current: ", currentSL, " Proposed: ", newSL);
                  }
               }
            }
            
            batches[i].movedToBE = true;
         }
      }
      
      // Check TP2 closed
      if(batches[i].movedToBE && !batches[i].movedToTP2)
      {
         bool tp2Closed = true;
         if(batches[i].ticket2 > 0)
         {
            string comment2 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP2";
            tp2Closed = !HasPositionByComment(comment2);
         }
         
         if(tp2Closed && batches[i].ticket3 > 0)
         {
            // TP3 runner: do not lock SL to TP2; keep room for continuation
            // TP3 remains at breakeven level (set when TP1 closed) to allow runner behavior
            batches[i].movedToTP2 = true;
            if(InpVerboseLogs)
               Print("TP2 closed. TP3 runner active (SL remains at breakeven). Batch: ", batches[i].batchId);
         }
      }
      
      // TP3 ATR-based trailing stop (only after TP2 closes)
      if(Enable_TP3_Trailing && batches[i].movedToTP2)
      {
         string comment3 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP3";
         ulong ticket3 = 0;
         if(FindPositionTicketByComment(MagicNumber, _Symbol, comment3, ticket3))
         {
            if(positionInfo.SelectByTicket(ticket3))
            {
               // Get current TP3 position details
               double currentSL = positionInfo.StopLoss();
               double currentTP = positionInfo.TakeProfit();
               
               // Get ATR value for trailing distance
               double atrBuffer[];
               ArraySetAsSeries(atrBuffer, true);
               if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0 && atrBuffer[0] > 0)
               {
                  double atrValue = atrBuffer[0];
                  double trailDistance = atrValue * TP3_Trail_ATR_Multiplier;
                  
                  // Calculate breakeven level (same as when TP1 closed)
                  double beBuffer = MathMax(Breakeven_Buffer_Points * point, spreadPoints * Breakeven_Buffer_Multiplier * point);
                  double breakevenLevel = batches[i].entryPrice;
                  if(batches[i].direction == 1)  // BUY
                     breakevenLevel = batches[i].entryPrice + beBuffer;
                  else  // SELL
                     breakevenLevel = batches[i].entryPrice - beBuffer;
                  
                  // Calculate proposed trailing SL
                  double proposedSL = currentSL;
                  bool shouldModify = false;
                  
                  if(batches[i].direction == 1)  // BUY
                  {
                     proposedSL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailDistance;
                     // Conditions: proposedSL > currentSL AND proposedSL >= breakevenLevel
                     if(proposedSL > currentSL && proposedSL >= breakevenLevel)
                        shouldModify = true;
                  }
                  else  // SELL
                  {
                     proposedSL = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailDistance;
                     // Conditions: proposedSL < currentSL AND proposedSL <= breakevenLevel
                     if(proposedSL < currentSL && proposedSL <= breakevenLevel)
                        shouldModify = true;
                  }
                  
                  // Modify position if conditions pass
                  if(shouldModify)
                  {
                     if(trade.PositionModify(ticket3, proposedSL, currentTP))
                     {
                        batches[i].ticket3 = ticket3;
                        if(InpVerboseLogs)
                           Print("TP3 trailing activated. Batch: ", batches[i].batchId, " New SL: ", proposedSL, " Old SL: ", currentSL);
                     }
                     // Fail silently if broker rejects (no forced close, no error spam)
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check invalidations                                              |
//+------------------------------------------------------------------+
void CheckInvalidations()
{
   if(!UseInvalidation)
      return;
   
   datetime currentTime = TimeCurrent();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spreadPoints = GetSpreadPoints();
   double invBuffer = MathMax(Invalidation_Buffer_Points * point, spreadPoints * Invalidation_Buffer_Multiplier * point);
   
   for(int i = 0; i < ArraySize(batches); i++)
   {
      if(batches[i].invalidationTriggered)
         continue;
      
      if(currentTime > batches[i].invalidateExpiry)
         continue;  // Past invalidation window
      
      bool invalidated = false;
      
      // Invalidation checks use opposite side (where stops are triggered)
      // BUY invalidated when Bid (stop trigger side) goes below invalidateLevel
      // SELL invalidated when Ask (stop trigger side) goes above invalidateLevel
      if(batches[i].direction == 1)  // Buy: check Bid (stop trigger side)
      {
         if(bid <= batches[i].invalidateLevel - invBuffer)
            invalidated = true;
      }
      else  // Sell: check Ask (stop trigger side)
      {
         if(ask >= batches[i].invalidateLevel + invBuffer)
            invalidated = true;
      }
      
      if(invalidated)
      {
         // Close all remaining positions by comment (with retry)
         string comment1 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP1";
         string comment2 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP2";
         string comment3 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP3";
         
         bool closed1 = ClosePositionByComment(MagicNumber, _Symbol, comment1);
         bool closed2 = ClosePositionByComment(MagicNumber, _Symbol, comment2);
         bool closed3 = ClosePositionByComment(MagicNumber, _Symbol, comment3);
         
         // Retry once if any failed (avoid spam - only retry once per invalidation)
         if(!closed1 || !closed2 || !closed3)
         {
            Sleep(50);  // Brief pause before retry
            if(!closed1) closed1 = ClosePositionByComment(MagicNumber, _Symbol, comment1);
            if(!closed2) closed2 = ClosePositionByComment(MagicNumber, _Symbol, comment2);
            if(!closed3) closed3 = ClosePositionByComment(MagicNumber, _Symbol, comment3);
         }
         
         // Mark as invalidated (state flag - batch will be removed only when all positions are closed)
         batches[i].invalidationTriggered = true;
         
         if(InpVerboseLogs)
         {
            Print("Batch ", batches[i].batchId, " invalidated. Level: ", batches[i].invalidateLevel, 
                  " Current: ", (batches[i].direction == 1 ? bid : ask),
                  " Closed: TP1=", closed1, " TP2=", closed2, " TP3=", closed3);
            if(!closed1 || !closed2 || !closed3)
               Print("WARNING: Some positions failed to close on invalidation. Batch will remain until all closed.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cleanup batches                                                  |
//+------------------------------------------------------------------+
void CleanupBatches()
{
   for(int i = ArraySize(batches) - 1; i >= 0; i--)
   {
      bool allClosed = true;
      
      // Check each leg - only mark as closed if position doesn't exist
      if(batches[i].ticket1 > 0)
      {
         string comment1 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP1";
         if(HasPositionByComment(comment1))
            allClosed = false;
      }
      
      if(batches[i].ticket2 > 0)
      {
         string comment2 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP2";
         if(HasPositionByComment(comment2))
            allClosed = false;
      }
      
      if(batches[i].ticket3 > 0)
      {
         string comment3 = "YURI#" + IntegerToString(batches[i].batchId) + "#TP3";
         if(HasPositionByComment(comment3))
            allClosed = false;
      }
      
      // Only remove batch when ALL positions are confirmed closed
      // invalidationTriggered is just a state flag, not a deletion trigger
      // This ensures management continues even if invalidation close failed
      if(allClosed)
      {
         if(InpVerboseLogs && batches[i].invalidationTriggered)
            Print("Removing batch ", batches[i].batchId, " - all positions closed (was invalidated)");
         else if(InpVerboseLogs)
            Print("Removing batch ", batches[i].batchId, " - all positions closed normally");
         
         ArrayRemove(batches, i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Rebuild batches from open positions                              |
//+------------------------------------------------------------------+
void RebuildBatchesFromPositions()
{
   // Scan all positions with our magic number
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == MagicNumber && positionInfo.Symbol() == _Symbol)
         {
            string comment = positionInfo.Comment();
            int pos = StringFind(comment, "YURI#");
            if(pos >= 0)
            {
               // Extract batch ID
               string batchIdStr = "";
               int pos2 = StringFind(comment, "#", pos + 5);
               if(pos2 > pos + 5)
               {
                  batchIdStr = StringSubstr(comment, pos + 5, pos2 - pos - 5);
                  int batchId = (int)StringToInteger(batchIdStr);
                  
                  // Check if batch already exists
                  bool batchExists = false;
                  int batchIdx = -1;
                  for(int j = 0; j < ArraySize(batches); j++)
                  {
                     if(batches[j].batchId == batchId)
                     {
                        batchExists = true;
                        batchIdx = j;
                        break;
                     }
                  }
                  
                  if(!batchExists)
                  {
                     // Create new batch - reconstruct from position data
                     BatchInfo batch;
                     batch.batchId = batchId;
                     batch.direction = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
                     batch.entryPrice = positionInfo.PriceOpen();
                     batch.slInitial = positionInfo.StopLoss();
                     batch.signalTime = (datetime)positionInfo.Time();
                     
                     // Recover TP from position (all legs should have same TP values)
                     batch.tp1 = positionInfo.TakeProfit();
                     batch.tp2 = positionInfo.TakeProfit();
                     batch.tp3 = positionInfo.TakeProfit();
                     
                     batch.ticket1 = 0;
                     batch.ticket2 = 0;
                     batch.ticket3 = 0;
                     batch.invalidationTriggered = false;
                     
                     // Determine which TP this is and decode invalidation level
                     double decodedInvLevel = DecodeInvLevelFromComment(comment, batch.entryPrice);
                     
                     if(StringFind(comment, "#TP1") >= 0)
                     {
                        batch.ticket1 = positionInfo.Ticket();
                        if(decodedInvLevel > 0)
                           batch.invalidateLevel = decodedInvLevel;
                     }
                     else if(StringFind(comment, "#TP2") >= 0)
                     {
                        batch.ticket2 = positionInfo.Ticket();
                        if(decodedInvLevel > 0)
                           batch.invalidateLevel = decodedInvLevel;
                     }
                     else if(StringFind(comment, "#TP3") >= 0)
                     {
                        batch.ticket3 = positionInfo.Ticket();
                        if(decodedInvLevel > 0)
                           batch.invalidateLevel = decodedInvLevel;
                     }
                     
                     // If invalidation level not found in comment, set expiry to now (disable invalidation)
                     if(batch.invalidateLevel <= 0)
                     {
                        batch.invalidateLevel = (batch.direction == 1) ? 
                           batch.entryPrice - 1000 * SymbolInfoDouble(_Symbol, SYMBOL_POINT) :  // Far below for BUY
                           batch.entryPrice + 1000 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);   // Far above for SELL
                        batch.invalidateExpiry = TimeCurrent();  // Disable by setting expiry to now
                        if(InpVerboseLogs)
                           Print("WARNING: Batch ", batchId, " - invalidation level not found in comment, invalidation disabled");
                     }
                     else
                     {
                        batch.invalidateExpiry = batch.signalTime + Invalidation_Window_Bars * PeriodSeconds(_Period);
                     }
                     
                     // Determine movedToBE: TP1 should be closed if movedToBE
                     string comment1Check = "YURI#" + IntegerToString(batchId) + "#TP1";
                     batch.movedToBE = !HasPositionByComment(comment1Check);
                     
                     // Determine movedToTP2: TP2 should be closed if movedToTP2
                     string comment2Check = "YURI#" + IntegerToString(batchId) + "#TP2";
                     batch.movedToTP2 = batch.movedToBE && !HasPositionByComment(comment2Check);
                     
                     int size = ArraySize(batches);
                     ArrayResize(batches, size + 1);
                     batches[size] = batch;
                     
                     if(nextBatchId <= batchId)
                        nextBatchId = batchId + 1;
                     
                     if(InpVerboseLogs)
                        Print("Rebuilt batch ", batchId, " from position. Entry: ", batch.entryPrice, " TP: ", batch.tp1, 
                              " movedToBE: ", batch.movedToBE, " movedToTP2: ", batch.movedToTP2);
                  }
                  else
                  {
                     // Update existing batch - add this leg
                     double decodedInvLevel = DecodeInvLevelFromComment(comment, batches[batchIdx].entryPrice);
                     
                     if(StringFind(comment, "#TP1") >= 0)
                     {
                        batches[batchIdx].ticket1 = positionInfo.Ticket();
                        if(batches[batchIdx].tp1 <= 0)
                           batches[batchIdx].tp1 = positionInfo.TakeProfit();
                     }
                     else if(StringFind(comment, "#TP2") >= 0)
                     {
                        batches[batchIdx].ticket2 = positionInfo.Ticket();
                        if(batches[batchIdx].tp2 <= 0)
                           batches[batchIdx].tp2 = positionInfo.TakeProfit();
                     }
                     else if(StringFind(comment, "#TP3") >= 0)
                     {
                        batches[batchIdx].ticket3 = positionInfo.Ticket();
                        if(batches[batchIdx].tp3 <= 0)
                           batches[batchIdx].tp3 = positionInfo.TakeProfit();
                     }
                     
                     // Update invalidation level if not already set and found in comment
                     if(decodedInvLevel > 0 && batches[batchIdx].invalidateLevel <= 0)
                     {
                        batches[batchIdx].invalidateLevel = decodedInvLevel;
                        batches[batchIdx].invalidateExpiry = batches[batchIdx].signalTime + Invalidation_Window_Bars * PeriodSeconds(_Period);
                     }
                     
                     // Update movedToBE/movedToTP2 based on current state
                     string comment1Check = "YURI#" + IntegerToString(batchId) + "#TP1";
                     batches[batchIdx].movedToBE = !HasPositionByComment(comment1Check);
                     
                     string comment2Check = "YURI#" + IntegerToString(batchId) + "#TP2";
                     batches[batchIdx].movedToTP2 = batches[batchIdx].movedToBE && !HasPositionByComment(comment2Check);
                  }
               }
            }
         }
      }
   }
   
   if(InpVerboseLogs && ArraySize(batches) > 0)
      Print("Rebuilt ", ArraySize(batches), " batches from open positions");
}
//+------------------------------------------------------------------+
