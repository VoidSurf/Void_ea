//+------------------------------------------------------------------+
//|                                                      void_ea.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

input int      AtrPeriod=14;      // Atr Period
input double      Vervort_fast_tema_period=12.0;   // Fast tema
input double      Vervort_slow_tema_period=12.0;   // Fast tema
input double risk=2; // Risk per trade

double our_buffer[];
double p_close;
int verwort_handle;
int atr_handle;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   SetIndexBuffer(0,our_buffer,INDICATOR_DATA);
   ResetLastError();
   
   verwort_handle = iCustom(NULL,0,"Examples\\Vervoort_Crossover_histo.ex5",12.0,5,12.0);
   Print("verwort_handle = ",verwort_handle,"  error = ",GetLastError());
   
   atr_handle = iATR(NULL,0,AtrPeriod);
   Print("atr_handle = ",atr_handle,"  error = ",GetLastError());
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   int FillingMode=(int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   
   
   
   static datetime Old_Time;
   datetime New_Time[1];
   
   bool IsNewBar=false;

// copying the last bar time to the element New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,New_Time);
   if(copied>0) // ok, the data has been copied successfully
     {
     
      if(Old_Time!=New_Time[0]) // if old time isn't equal to new bar time
        {
         IsNewBar=true;   // if it isn't a first call, the new bar has appeared
         if(MQL5InfoInteger(MQL5_DEBUGGING)) Print("We have new bar here ",New_Time[0]," old time was ",Old_Time);
         Old_Time=New_Time[0];            // saving bar time
        }
     }
   else
     {
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
     }
     
     
     if(IsNewBar==false)
     {
      return;
     }
     
     
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);      // Initialization of mrequest structure
   
   if(!SymbolInfoTick(_Symbol,latest_price))
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
     }

//--- Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
     }
     
     
     bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position

   if(PositionSelect(_Symbol)==true) // we have an opened position
     {
     return;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         Buy_opened=true;  //It is a Buy
        }
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         Sell_opened=true; // It is a Sell
        }
     }
     
     p_close=mrate[1].close;
   
   
   double verw[];
   ArraySetAsSeries(verw, true);
   if (CopyBuffer(verwort_handle,1,0,20,verw) < 0){Print("CopyBufferMA1 error =",GetLastError());}
   Print(verw[0]);
   static double old_verw_value;
   double new_verw_value = verw[1];
   bool isColorChange = false;
   Print("0: " + verw[0] + " 1: " + verw[1] + " 2: " + verw[2]);
   Print("OLD:"+old_verw_value + " NEW:" + new_verw_value);
   if(new_verw_value != old_verw_value)
   {
      Print("COLOR CHANGED");
    isColorChange = true;
    old_verw_value = new_verw_value;
   }
   
   if(!isColorChange){return;}
   
   double iATRBuffer[];
   ArraySetAsSeries(iATRBuffer, true);
   if (CopyBuffer(atr_handle,0,0,20,iATRBuffer) < 0){Print("copy buffer error =",GetLastError());}
   
   double atrValue = NormalizeDouble(iATRBuffer[1] *100000,0);
   double oneAndHalfAtr = 1.5*atrValue;
   double money_to_risk = AccountInfoDouble(ACCOUNT_BALANCE) * (risk/100);
   double lotSize = NormalizeDouble(money_to_risk/(1.5*(atrValue/10)),2);
   
   bool Buy_Condition_1=(new_verw_value == 1);

//--- Putting all together   
   if(Buy_Condition_1)
   {
     
      // any opened Buy position?
      if(Buy_opened)
        {
         Alert("We already have a Buy Position!!!");
         return;    // Don't open a new Buy Position
        }
      ZeroMemory(mrequest);
      mrequest.action = TRADE_ACTION_DEAL;                                  // immediate order execution
      mrequest.price = NormalizeDouble(latest_price.ask,_Digits);           // latest ask price
      mrequest.sl = NormalizeDouble(latest_price.ask - oneAndHalfAtr*_Point,_Digits); // Stop Loss
      mrequest.tp = NormalizeDouble(latest_price.ask + atrValue*_Point,_Digits); // Take Profit
      mrequest.symbol = _Symbol;                                            // currency pair
      mrequest.volume = lotSize;                                                 // number of lots to trade
      mrequest.magic = 1337;                                             // Order Magic Number
      mrequest.type = ORDER_TYPE_BUY;                                        // Buy Order
      mrequest.type_filling = ORDER_FILLING_IOC;                             // Order execution type
      mrequest.deviation=100;                                                // Deviation from current price
      //--- send order
      OrderSend(mrequest,mresult);
      // get the result code
      if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
        {
         Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
        }
      else
        {
         Alert("The Buy order request could not be completed -error:",GetLastError());
         ResetLastError();           
         return;
        }
    }
    
   bool Sell_Condition_1 = (new_verw_value == 2);  // MA-8 decreasing downwards
                       // -DI greater than +DI

//--- Putting all together
   if(Sell_Condition_1)
     {
      
         // any opened Sell position?
         if(Sell_opened)
           {
            Alert("We already have a Sell position!!!");
            return;    // Don't open a new Sell Position
           }
         ZeroMemory(mrequest);
         mrequest.action=TRADE_ACTION_DEAL;                                // immediate order execution
         mrequest.price = NormalizeDouble(latest_price.bid,_Digits);           // latest Bid price
         mrequest.sl = NormalizeDouble(latest_price.bid + oneAndHalfAtr*_Point,_Digits); // Stop Loss
         mrequest.tp = NormalizeDouble(latest_price.bid - atrValue*_Point,_Digits); // Take Profit
         mrequest.symbol = _Symbol;                                          // currency pair
         mrequest.volume = lotSize;                                              // number of lots to trade
         mrequest.magic = 1337;                                          // Order Magic Number
         mrequest.type= ORDER_TYPE_SELL;                                     // Sell Order
         mrequest.type_filling = ORDER_FILLING_IOC;                          // Order execution type
         mrequest.deviation=100;                                             // Deviation from current price
         //--- send order
         OrderSend(mrequest,mresult);
         // get the result code
         if(mresult.retcode==10009 || mresult.retcode==10008) //Request is completed or order placed
           {
            Alert("A Sell order has been successfully placed with Ticket#:",mresult.order,"!!");
           }
         else
           {
            Alert("The Sell order request could not be completed -error:",GetLastError());
            ResetLastError();
            return;
           }
        
     }
    
    
   return;
   
   
   
  }
//+------------------------------------------------------------------+
