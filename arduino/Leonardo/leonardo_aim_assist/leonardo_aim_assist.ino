// Pick ONE profile before including the library
#define PROFILE_WINDOWS    // or PROFILE_MAC / PROFILE_UBUNTU / PROFILE_ANDROID / PROFILE_WINXP

#include <Arduino.h>
#include <HID.h>
#include <AbsMouse.h>   // absmouse library for native‑USB boards

// ----- User settings -----
static const uint32_t BAUD        = 115200;
static const uint16_t SCREEN_W    = 1920;     // screen width in pixels
static const uint16_t SCREEN_H    = 1080;     // screen height in pixels
static const float    ALPHA       = 0.42f;    // smoothing factor (0..1)
static const uint16_t DEADZONE_HID= 30;       // ignore tiny error (HID units)
static const uint16_t MAX_STEP_HID= 2500;     // clamp per‑update (HID units)
static const uint32_t WATCHDOG_MS = 120;      // stop if no packet within this
static const bool     REQUIRE_ENABLE = true;  // require ENABLE bit
static const bool     REQUIRE_ADS    = false; // require ADS bit as well

// ----- Packet constants (host protocol) -----
static const uint8_t  MAGIC0=0xAA, MAGIC1=0x55, PROTO_VER=1;
static const uint8_t  FLAG_ENABLE=1<<0, FLAG_ADS=1<<1, FLAG_USE_BIAS=1<<2, FLAG_MODE_PIX=1<<3;
static const uint8_t  PKT_SIZE=18;

// ----- Helpers -----
static inline uint16_t rd_u16(const uint8_t* p){return (uint16_t)p[0] | ((uint16_t)p[1] << 8);}
static inline int16_t  rd_i16(const uint8_t* p){return (int16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));}
static inline uint16_t clamp_u16(int32_t v,uint16_t lo,uint16_t hi){ if(v<(int32_t)lo)return lo; if(v>(int32_t)hi)return hi; return (uint16_t)v; }

// CRC16/X25 for integrity
static uint16_t crc16_x25(const uint8_t* d, size_t n){
  auto refl8=[](uint8_t x){uint8_t r=0; for(uint8_t i=0;i<8;i++) r=(r<<1)|((x>>i)&1); return r;};
  auto refl16=[](uint16_t x){uint16_t r=0; for(uint8_t i=0;i<16;i++) r=(r<<1)|((x>>i)&1); return r;};
  uint16_t crc=0xFFFF;
  for(size_t i=0;i<n;i++){
    uint8_t b=refl8(d[i]);
    crc^=(uint16_t)b<<8;
    for(uint8_t j=0;j<8;j++) crc=(crc&0x8000)? (crc<<1)^0x1021 : (crc<<1);
  }
  return refl16(crc)^0xFFFF;
}

// map pixels -> HID 0..32767
static inline uint16_t pixelsToHID(uint16_t p, uint16_t dimPx){
  if(dimPx<=1) return 0;
  uint32_t v=(uint32_t)p*32767UL/(uint32_t)(dimPx-1);
  if(v>32767UL) v=32767UL;
  return (uint16_t)v;
}

// ----- State -----
uint8_t  rxBuf[PKT_SIZE];
uint8_t  rxCount=0;
uint32_t lastGood=0;
uint16_t curX=16384, curY=16384;
float    filtX=16384.f, filtY=16384.f;

static void setAbs(uint16_t x,uint16_t y){
  curX = x; curY = y;
  AbsMouse.move(x, y);  // absmouse sets absolute coords internally
}

void setup(){
  Serial.begin(BAUD);
  AbsMouse.init(SCREEN_W, SCREEN_H, true);  // scale to screen size and auto‑report
  setAbs(curX, curY);                      // centre cursor
  filtX=curX; filtY=curY; lastGood=millis();
}

void loop(){
  // Read bytes from host
  while(Serial.available()>0){
    uint8_t b=(uint8_t)Serial.read();
    if(rxCount==0){ if(b!=MAGIC0) continue; rxBuf[rxCount++]=b; continue; }
    if(rxCount==1){ if(b!=MAGIC1){ rxCount=0; continue; } rxBuf[rxCount++]=b; continue; }
    rxBuf[rxCount++]=b;
    if(rxCount!=PKT_SIZE) continue;

    // Validate packet
    if(rxBuf[2]!=PROTO_VER){ rxCount=0; continue; }
    uint16_t recvCrc=rd_u16(&rxBuf[PKT_SIZE-2]);
    uint16_t calcCrc=crc16_x25(rxBuf,PKT_SIZE-2);
    if(recvCrc!=calcCrc){ rxCount=0; continue; }

    // parse fields
    uint8_t  flags = rxBuf[3];
    uint16_t xin   = rd_u16(&rxBuf[4]);
    uint16_t yin   = rd_u16(&rxBuf[6]);
    int16_t  bx    = rd_i16(&rxBuf[8]);
    int16_t  by    = rd_i16(&rxBuf[10]);

    // gating
    bool enabled = true;
    if(REQUIRE_ENABLE) enabled = (flags & FLAG_ENABLE);
    if(enabled && REQUIRE_ADS) enabled = (flags & FLAG_ADS);
    if(!enabled){ lastGood=millis(); rxCount=0; continue; }

    // map to HID coordinates (0..32767)
    uint16_t tx, ty;
    if(flags & FLAG_MODE_PIX){ // host sends pixel coordinates
      tx=pixelsToHID(xin, SCREEN_W);
      ty=pixelsToHID(yin, SCREEN_H);
    }else{
      tx=(xin>32767)?32767:xin;
      ty=(yin>32767)?32767:yin;
    }
    // optional bias
    if(flags & FLAG_USE_BIAS){
      int32_t sx=(int32_t)tx+bx, sy=(int32_t)ty+by;
      if(sx<0)sx=0; if(sx>32767)sx=32767;
      if(sy<0)sy=0; if(sy>32767)sy=32767;
      tx=(uint16_t)sx; ty=(uint16_t)sy;
    }

    // compute error in HID space
    int32_t ex=(int32_t)tx-(int32_t)curX;
    int32_t ey=(int32_t)ty-(int32_t)curY;
    if(abs(ex)<(int32_t)DEADZONE_HID) ex=0;
    if(abs(ey)<(int32_t)DEADZONE_HID) ey=0;
    if(ex> (int32_t)MAX_STEP_HID) ex= MAX_STEP_HID;
    if(ex<-(int32_t)MAX_STEP_HID) ex=-MAX_STEP_HID;
    if(ey> (int32_t)MAX_STEP_HID) ey= MAX_STEP_HID;
    if(ey<-(int32_t)MAX_STEP_HID) ey=-MAX_STEP_HID;

    // smoothing
    float nextX=(float)curX+(float)ex, nextY=(float)curY+(float)ey;
    filtX = ALPHA*nextX + (1.f-ALPHA)*filtX;
    filtY = ALPHA*nextY + (1.f-ALPHA)*filtY;

    uint16_t outX=clamp_u16((int32_t)lroundf(filtX), 0, 32767);
    uint16_t outY=clamp_u16((int32_t)lroundf(filtY), 0, 32767);
    setAbs(outX, outY);

    lastGood=millis();
    rxCount=0;
  }

  // Stop motion if data stops
  if((millis()-lastGood)>WATCHDOG_MS){
    filtX=curX; filtY=curY;
  }
}
