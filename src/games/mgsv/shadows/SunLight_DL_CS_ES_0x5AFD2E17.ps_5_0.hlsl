// MGSV sun (directional) light with cascade shadow ? CRC32 0x5AFD2E17, ps_5_0.
//
// Original source: SunLight_DL_CS_ES_ps.hlsl
// Decompiled from the retail DXBC with 3Dmigoto (bin/cmd_Decompiler.exe).
// The register-level body below is the vanilla decompilation, kept verbatim so the
// baseline is provably equivalent. Contact hardening edits are marked "PCSS".
//
// Vanilla shadow filter (what PCSS replaces):
//   4 x SampleCmp(t3, s15) at +/-0.5 +/-0.125 texel, dithered from t12,
//   then shadow = (1 - average)^2.
//   Fixed radius => no contact hardening.
//
// Shadow map: t3 g_ShadowTexture, 8192x8192 R24_UNORM_X8_TYPELESS view of D24S8,
//   2x2 atlas of 4 cascades x 4096x4096.
// ---- Created with 3Dmigoto v1.3.16 on Thu Oct 15 03:15:09 2026

cbuffer cPSScene : register(b2)
{

  struct
  {
    float4x4 m_projectionView;
    float4x4 m_projection;
    float4x4 m_view;
    float4x4 m_shadowProjection;
    float4x4 m_shadowProjection2;
    float4 m_eyepos;
    float4 m_projectionParam;
    float4 m_viewportSize;
    float4 m_exposure;
    float4 m_fogParam[3];
    float4 m_fogColor;
    float4 m_cameraCenterOffset;
    float4 m_shadowMapResolutions;
  } g_psScene : packoffset(c0);

}

cbuffer cPSObject : register(b5)
{

  struct
  {
    float4x4 m_viewWorld;
    float4x4 m_world;
    float4 m_useWeightCount;
    float4 m_localParam[4];
  } g_psObject : packoffset(c0);

}

cbuffer cPSLight : register(b3)
{

  struct
  {
    float4 m_lightParams[11];
  } g_psLight : packoffset(c0);

}

SamplerState g_samplerPoint_Wrap_s : register(s8);
SamplerState g_samplerPoint_Clamp_s : register(s9);
SamplerState g_samplerLinear_Wrap_s : register(s10);
SamplerState g_samplerLinear_Clamp_s : register(s11);
SamplerComparisonState g_samplerComparisonLess_Linear_Clmap_s : register(s15);
Texture2D<float4> g_NormalTexture : register(t0);
Texture2D<float4> g_SpecularTexture : register(t1);
Texture2D<float4> g_DepthTexture : register(t2);
Texture2D<float4> g_ShadowTexture : register(t3);
Texture2D<float4> g_CloudTexture : register(t4);
Texture3D<float4> g_lut2 : register(t8);
Texture2D<float4> g_lut1 : register(t9);
Texture2D<float4> g_MaterialTexture : register(t10);
Texture2D<float4> g_RandomTexture : register(t12);
Texture2D<float4> g_SkyReflectTexture : register(t15);

// ---------------------------------------------------------------------------
// PCSS (contact hardening) tuning.
// During devkit iteration these are edited and the shader is reloaded live.
// They move into the cb13 ShaderInjectData buffer when this ships.
// ---------------------------------------------------------------------------
#define PCSS_STRENGTH        1.0   // 0 = vanilla 4-tap PCF, 1 = full PCSS
#define PCSS_SCALE           800.0 // penumbra = (receiverZ - blockerZ) * SCALE
#define PCSS_BLOCKER_RADIUS  16.0  // blocker search radius, cascade texels
#define PCSS_BIAS            0.002 // depth margin that excludes the receiver's own surface
#define PCSS_MIN_PENUMBRA    1.0   // penumbra floor, texels (keeps contacts crisp)
#define PCSS_MAX_PENUMBRA    12.0  // penumbra ceiling, texels (perf + bleed guard)
#define PCSS_BLOCKER_TAPS    16
#define PCSS_PCF_TAPS        16

// 16-point Poisson disk, unit radius. Same set is used for the blocker search
// and the PCF so both stay on the same sample pattern.
static const float2 kPcssPoisson16[16] = {
    float2(-0.94201624, -0.39906216),
    float2( 0.94558609, -0.76890725),
    float2(-0.09418410, -0.92938870),
    float2( 0.34495938,  0.29387760),
    float2(-0.91588581,  0.45771432),
    float2(-0.81544232, -0.87912464),
    float2(-0.38277543,  0.27676845),
    float2( 0.97484398,  0.75648379),
    float2( 0.44323325, -0.97511554),
    float2( 0.53742981, -0.47373420),
    float2(-0.26496911, -0.41893023),
    float2( 0.79197514,  0.19090188),
    float2(-0.24188840,  0.99706507),
    float2(-0.81409955,  0.91437590),
    float2( 0.19984126,  0.78641367),
    float2( 0.14383161, -0.14100790),
};

// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_Target0,
  out float4 o1 : SV_Target1)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = float4(-0.5,-0.5,-0.5,-0.5) + v0.xyxy;
  r1.xyz = v2.xyw;
  r1.xyz = r1.xyz;
  r1.xy = r1.xy / r1.zz;
  r1.xy = r1.xy;
  r1.xy = r1.xy;
  r1.xy = r1.xy;
  r2.xyz = g_NormalTexture.Sample(g_samplerPoint_Wrap_s, r1.xy).xyz;
  r2.xyz = r2.xyz;
  r3.xyzw = g_SpecularTexture.Sample(g_samplerPoint_Wrap_s, r1.xy).yxzw;
  r1.x = g_DepthTexture.Sample(g_samplerPoint_Wrap_s, r1.xy).x;
  r1.x = r1.x;
  r2.xyz = r2.xyz;
  r1.yz = float2(2,2) * r2.xy;
  r1.yz = float2(-1,-1) + r1.yz;
  r1.w = r2.z * r2.z;
  r1.w = 2 * r1.w;
  r2.z = -1 + r1.w;
  r1.w = r2.z * r2.z;
  r1.w = -r1.w;
  r1.w = 1 + r1.w;
  r4.xy = r1.yz * r1.ww;
  r1.y = dot(r1.yz, r1.yz);
  r1.y = r1.w * r1.y;
  r1.y = 1.00000001e-007 + r1.y;
  r1.y = rsqrt(r1.y);
  r2.xy = r4.xy * r1.yy;
  r2.xy = r2.xy;
  r2.z = r2.z;
  r2.xyz = r2.xyz;
  r1.y = r3.y;
  r3.x = r3.x;
  r3.z = r3.z;
  r3.w = r3.w;
  r2.xyz = r2.xyz;
  r3.z = r3.z;
  r3.x = r3.x;
  r1.y = r1.y;
  r3.w = r3.w;
  r1.x = r1.x;
  r1.x = r1.x;
  r4.xyz = v1.xyw;
  r1.x = r1.x;
  r4.xyz = r4.xyz;
  r1.zw = r4.xy / r4.zz;
  r4.xy = -g_psScene.m_cameraCenterOffset.xy;
  r1.zw = r4.xy + r1.zw;
  r1.x = r1.x;
  r4.xyzw = g_psScene.m_projectionParam.xyzw;
  r1.zw = r4.xy * r1.zw;
  r2.w = -r4.w;
  r1.x = r2.w + r1.x;
  r4.z = r4.z / r1.x;
  r5.z = r4.z;
  r4.xy = r5.zz * r1.zw;
  r5.xy = r4.xy;
  r4.w = 1;
  r5.xy = r5.xy;
  r5.z = r5.z;
  r5.w = 1;
  r5.xyzw = r5.xyzw;
  r1.x = dot(r5.xyz, r5.xyz);
  r1.x = rsqrt(r1.x);
  r1.xzw = r5.xyz * r1.xxx;
  r5.xyzw = r5.xyzw;
  r1.xzw = r1.xzw;
  r6.xyz = g_psLight.m_lightParams[0].xyz;
  r7.xyz = g_psLight.m_lightParams[1].xyz * g_psScene.m_exposure.zzz;
  r7.w = g_psLight.m_lightParams[1].w;
  r6.xyz = r6.xyz;
  r7.xyzw = r7.xyzw;
  r5.xyzw = r5.xyzw;
  r0.xyzw = r0.xyzw;
  r5.xyzw = r5.xyzw;
  r0.xyzw = r0.xyzw;
  r8.x = 0.5 / g_psScene.m_shadowMapResolutions.x;
  r8.y = 0.5 / g_psScene.m_shadowMapResolutions.x;
  r9.x = dot(r4.xyzw, g_psScene.m_shadowProjection._m00_m10_m20_m30);
  r9.y = dot(r4.xyzw, g_psScene.m_shadowProjection._m01_m11_m21_m31);
  r9.z = dot(r4.xyzw, g_psScene.m_shadowProjection._m02_m12_m22_m32);
  r9.xyz = r9.xyz;
  r9.xyz = r9.xyz;
  r4.xy = r0.zw;
  r2.w = 1 / g_psScene.m_shadowMapResolutions.x;
  r4.z = 8 * r2.w;
  r4.z = -r4.z;
  r4.z = 1 + r4.z;
  r8.zw = r4.zz * r4.zz;
  r4.w = g_psScene.m_shadowProjection2._m33;
  r4.w = r4.w;
  r6.w = r8.w;
  r4.w = cmp(0 != r4.w);
  if (r4.w != 0) {
    r4.xy = float2(0.03125,0.03125) * r4.xy;
    r4.xy = g_RandomTexture.Sample(g_samplerLinear_Wrap_s, r4.xy).xy;
    r4.x = max(r4.x, r4.y);
    r4.y = 0.00249999994 * r4.x;
    r4.x = g_psScene.m_shadowMapResolutions.x * r4.x;
    r4.x = r4.x / 4;
    r2.w = r4.x * r2.w;
    r2.w = -r2.w;
    r2.w = r4.z + r2.w;
    r2.w = r2.w * r2.w;
    r6.w = 1 * r2.w;
  } else {
    r4.y = 0;
  }
  r2.w = g_psScene.m_shadowProjection2._m30;
  r2.w = r2.w;
  r9.w = 0;
  r10.x = g_psScene.m_shadowProjection2._m00;
  r10.y = g_psScene.m_shadowProjection2._m01;
  r10.z = g_psScene.m_shadowProjection2._m02;
  r10.w = g_psScene.m_shadowProjection2._m03;
  r10.xyzw = r10.xyzw;
  r11.x = g_psScene.m_shadowProjection2._m10;
  r11.y = g_psScene.m_shadowProjection2._m11;
  r11.z = g_psScene.m_shadowProjection2._m12;
  r11.w = g_psScene.m_shadowProjection2._m13;
  r11.xyzw = r11.xyzw;
  r12.x = g_psScene.m_shadowProjection2._m20;
  r12.y = g_psScene.m_shadowProjection2._m21;
  r12.z = g_psScene.m_shadowProjection2._m22;
  r12.w = g_psScene.m_shadowProjection2._m23;
  r12.xyzw = r12.xyzw;
  r4.xzw = r10.www * r9.xyz;
  r10.xyz = r4.xzw + r10.xyz;
  r10.w = 1;
  r4.xzw = r11.www * r9.xyz;
  r11.xyz = r4.xzw + r11.xyz;
  r11.w = 2;
  r4.xzw = r12.www * r9.xyz;
  r12.xyz = r4.xzw + r12.xyz;
  r12.w = 3;
  r4.x = 1 + r9.z;
  r9.z = r4.x * r2.w;
  r4.x = 1 + r10.z;
  r10.z = r4.x * r2.w;
  r4.x = 1 + r11.z;
  r11.z = r4.x * r2.w;
  r4.x = 1 + r12.z;
  r12.z = r4.x * r2.w;
  r4.xz = r9.xy * r9.xy;
  r13.xy = r10.xy * r10.xy;
  r13.zw = r11.xy * r11.xy;
  r4.xz = cmp(r8.zw >= r4.xz);
  r4.xz = r4.xz ? float2(1,1) : float2(0,0);
  r2.w = cmp(r9.z >= r4.y);
  r2.w = r2.w ? 1 : 0;
  r8.zw = r6.ww;
  r13.xy = cmp(r8.zw >= r13.xy);
  r13.xy = r13.xy ? float2(1,1) : float2(0,0);
  r4.w = cmp(r10.z >= r4.y);
  r4.w = r4.w ? 1 : 0;
  r8.zw = cmp(r8.zw >= r13.zw);
  r8.zw = r8.zw ? float2(1,1) : float2(0,0);
  r4.y = cmp(r11.z >= r4.y);
  r4.y = r4.y ? 1 : 0;
  r4.x = r4.x * r4.z;
  r14.xyzw = r4.xxxx * r2.wwww;
  r2.w = r13.x * r13.y;
  r2.w = r2.w * r4.w;
  r4.x = r8.z * r8.w;
  r4.x = r4.x * r4.y;
  r4.y = -r14.w;
  r4.y = 1 + r4.y;
  r13.xyzw = r4.yyyy * r2.wwww;
  r2.w = -r13.w;
  r2.w = 1 + r2.w;
  r2.w = r4.y * r2.w;
  r4.xyzw = r4.xxxx * r2.wwww;
  r6.w = -r4.w;
  r6.w = 1 + r6.w;
  r2.w = r6.w * r2.w;
  r15.xyzw = float4(1,1,1,1) * r2.wwww;
  r9.xyzw = r14.xyzw * r9.xyzw;
  r10.xyzw = r13.xyzw * r10.xyzw;
  r9.xyzw = r10.xyzw + r9.xyzw;
  r4.xyzw = r11.xyzw * r4.xyzw;
  r4.xyzw = r9.xyzw + r4.xyzw;
  r9.xyzw = r15.xyzw * r12.xyzw;
  r4.xyzw = r9.wxyz + r4.wxyz;
  r4.w = max(9.99999997e-007, r4.w);
  r4.xyz = r4.xyz;
  r4.w = r4.w;
  r4.xyzw = r4.xyzw;
  r4.x = r4.x;
  // PCSS: blended cascade index, captured before r4.x is halved below.
  float pcssCascadeIndex = r4.x;
  r8.zw = float2(0.5,0.5) * r4.yz;
  r9.xy = float2(0.5,0.5) + r8.zw;
  r2.w = -r9.y;
  r9.z = 1 + r2.w;
  r8.zw = float2(0.5,0.5) * r9.xz;
  r9.xy = float2(2,2) * r8.xy;
  r9.xy = -r9.xy;
  r9.xy = float2(1,1) + r9.xy;
  r8.zw = min(r9.xy, r8.zw);
  r2.w = -1 + r4.x;
  r2.w = max(0, r2.w);
  r2.w = min(1, r2.w);
  r4.x = r4.x / 2;
  r6.w = -r2.w;
  r9.x = r6.w + r4.x;
  r9.y = 0.5 * r2.w;
  r8.zw = r9.xy + r8.zw;
  r4.yz = r8.zw + r8.xy;
  r4.yz = r4.yz;
  r4.w = r4.w;
  r0.xyzw = r0.xyzw;
  r4.yzw = r4.yzw;
  r0.xyzw = r0.xyzw;
  r4.yzw = r4.yzw;
  r0.xyzw = r0.xyzw;
  r0.xyzw = r0.xyzw / float4(2,2,2,2);
  r0.xyzw = frac(r0.xyzw);
  r0.xyzw = cmp(r0.xyzw >= float4(0.300000012,0.300000012,0.300000012,0.300000012));
  r0.xyzw = r0.xyzw ? float4(1,1,1,1) : float4(0,0,0,0);
  r0.xyzw = float4(2,2,2,2) * r0.xyzw;
  r0.xyzw = float4(-1,-1,-1,-1) + r0.xyzw;
  r0.xyzw = float4(0.125,0.125,0.125,0.125) * r0.xyzw;
  r0.xyzw = float4(0.5,0.5,-0.5,-0.5) + r0.xyzw;
  r8.xyzw = float4(1,1,1,1) / g_psScene.m_shadowMapResolutions.xxxx;
  r0.xyzw = r8.xyzw * r0.xyzw;
  r4.yzw = r4.yzw;
  r8.xy = r4.yz + r0.xy;
  r8.xy = r8.xy;
  r8.z = r4.w;
  r9.xyz = r8.xyz / float3(1,1,1);
  r2.w = g_ShadowTexture.SampleCmp(g_samplerComparisonLess_Linear_Clmap_s, r9.xy, r9.z).x;
  r2.w = 0 + r2.w;
  r9.xy = r4.yz + r0.zy;
  r9.xy = r9.xy;
  r9.z = r8.z;
  r9.xyz = r9.xyz / float3(1,1,1);
  r0.y = g_ShadowTexture.SampleCmp(g_samplerComparisonLess_Linear_Clmap_s, r9.xy, r9.z).x;
  r0.y = r2.w + r0.y;
  r9.xy = r4.yz + r0.xw;
  r9.xy = r9.xy;
  r9.z = r8.z;
  r9.xyz = r9.xyz / float3(1,1,1);
  r0.x = g_ShadowTexture.SampleCmp(g_samplerComparisonLess_Linear_Clmap_s, r9.xy, r9.z).x;
  r0.x = r0.y + r0.x;
  r8.xy = r4.yz + r0.zw;
  r8.xy = r8.xy;
  r0.yzw = r8.xyz / float3(1,1,1);
  r0.y = g_ShadowTexture.SampleCmp(g_samplerComparisonLess_Linear_Clmap_s, r0.yz, r0.w).x;
  r0.x = r0.x + r0.y;
  r0.x = 0.25 * r0.x;
  r0.x = 1 * r0.x;
  r0.x = -r0.x;
  r0.x = 1 + r0.x;
  r0.x = r0.x * r0.x;

  // =========================================================================
  // PCSS contact hardening (sun).
  //
  // Replaces the vanilla fixed-radius 4-tap PCF just above. Everything else in
  // this shader (cascade selection, blending, bias, cloud shadow, fades) is
  // untouched.
  //
  //   vanilla : lit = (1 - mean(SampleCmp))^2     fixed +/-0.5 texel radius
  //   PCSS    : penumbra from blocker distance    variable radius
  //
  // r0.x here is the vanilla lit factor (1 = fully lit, 0 = fully shadowed).
  // =========================================================================
  {
    const float  texel     = 1.0 / g_psScene.m_shadowMapResolutions.x;
    const float  atlasSize = g_psScene.m_shadowMapResolutions.x;
    const float2 baseUV    = r4.yz;
    const float  refZ      = r4.w;

    // Cascade tile window. Vanilla builds the atlas UV as
    //   0.5 * localUV + tileOffset
    // with tileOffset from the blended cascade index, so PCSS taps have to stay
    // inside [tileOffset, tileOffset + 0.5] or they bleed into the neighbour
    // cascade. tileOffset is reproduced exactly as vanilla computes it.
    const float2 tileOffset = float2(
        pcssCascadeIndex * 0.5 - clamp(pcssCascadeIndex - 1.0, 0.0, 1.0),
        0.5 * clamp(pcssCascadeIndex - 1.0, 0.0, 1.0));
    const float2 uvMin = tileOffset + 0.5 * texel;
    const float2 uvMax = tileOffset + 0.5 - 0.5 * texel;

    // Per-pixel rotation from the game's own 32x32 noise texture (t12) so the
    // disk does not band.
    const float2 noise = g_RandomTexture.Sample(g_samplerLinear_Wrap_s, (v0.xy - 0.5) * 0.03125).xy;
    const float  angle = noise.x * 6.28318530718;
    const float  cs    = cos(angle);
    const float  sn    = sin(angle);

    // 1. Blocker search on the raw shadow-map depth.
    //
    // t3 is an R24_UNORM_X8_TYPELESS view of the D24S8 cascade atlas, so the
    // depth is readable directly with the point sampler; no comparison sampler
    // needed. Blockers are texels closer to the light than the receiver, i.e.
    // a smaller depth. PCSS_BIAS keeps the receiver's own surface out of the
    // blocker set — the engine's caster bias makes it register as occluded,
    // which would otherwise average the blocker depth back up to the receiver
    // and flatten the penumbra.
    //
    // The light's ortho depth range is very wide, so receiver-to-blocker
    // distances land in the 0.001..0.02 range in normalised depth. PCSS_SCALE
    // converts that into cascade texels.
    float blockerSum    = 0.0;
    float blockerWeight = 0.0;
    [unroll] for (int i = 0; i < PCSS_BLOCKER_TAPS; ++i) {
      const float2 p  = kPcssPoisson16[i];
      const float2 rp = float2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
      const float2 uv = clamp(baseUV + rp * (PCSS_BLOCKER_RADIUS * texel), uvMin, uvMax);
      const float  d  = g_ShadowTexture.SampleLevel(g_samplerPoint_Clamp_s, uv, 0).x;
      const float  w  = (d < refZ - PCSS_BIAS) ? 1.0 : 0.0;
      blockerSum += d * w;
      blockerWeight += w;
    }

    // 2. Penumbra: wider where the blocker is far from the receiver.
    //
    // hasBlocker gates the whole effect: where the blocker search found nothing
    // the pixel is lit, and running a wide PCF there would pull neighbouring
    // shadow texels in and paint a halo around every shadow.
    const float hasBlocker = saturate(blockerWeight);
    const float avgBlocker = blockerSum / max(blockerWeight, 1.0);
    const float penumbra = clamp((refZ - avgBlocker) * PCSS_SCALE, PCSS_MIN_PENUMBRA, PCSS_MAX_PENUMBRA);

    // 3. Variable-radius PCF with the game's own comparison sampler.
    float avg = 0.0;
    [unroll] for (int j = 0; j < PCSS_PCF_TAPS; ++j) {
      const float2 p  = kPcssPoisson16[j];
      const float2 rp = float2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
      const float2 uv = clamp(baseUV + rp * (penumbra * texel), uvMin, uvMax);
      avg += g_ShadowTexture.SampleCmp(g_samplerComparisonLess_Linear_Clmap_s, uv, refZ).x;
    }
    avg /= (float)PCSS_PCF_TAPS;

    float pcssLit = 1.0 - avg;
    pcssLit *= pcssLit;  // keep vanilla's squaring

    r0.x = lerp(r0.x, pcssLit, PCSS_STRENGTH * hasBlocker);
  }

  r4.xy = float2(-0,-0);
  r4.z = -g_psLight.m_lightParams[8].x;
  r0.yzw = r5.xyz + r4.xyz;
  r0.y = dot(r0.yzw, r0.yzw);
  r0.y = sqrt(r0.y);
  r0.z = -g_psLight.m_lightParams[8].y;
  r0.y = r0.y + r0.z;
  r0.y = max(0, r0.y);
  r0.y = g_psLight.m_lightParams[6].x * r0.y;
  r0.y = max(0, r0.y);
  r0.y = min(1, r0.y);
  r0.z = cmp(r0.w >= 0);
  r0.z = r0.z ? 1 : 0;
  r0.y = r0.y * r0.z;
  r0.y = r0.y * r0.y;
  r0.z = -r0.x;
  r0.z = 1 + r0.z;
  r0.y = r0.y * r0.z;
  r0.x = r0.x + r0.y;
  r0.y = g_psLight.m_lightParams[6].w;
  r0.y = -r0.y;
  r0.x = r0.x + r0.y;
  r0.x = max(0, r0.x);
  r0.x = min(1, r0.x);
  r4.x = dot(g_psObject.m_localParam[0].xyzw, r5.xyzw);
  r4.y = dot(g_psObject.m_localParam[1].xyzw, r5.xyzw);
  r0.y = g_psObject.m_localParam[3].w;
  r0.z = g_psObject.m_localParam[3].z;
  r0.w = g_CloudTexture.Sample(g_samplerLinear_Wrap_s, r4.xy).x;
  r0.z = -0 + r0.z;
  r0.w = -0 + r0.w;
  r0.z = 1 / r0.z;
  r0.z = r0.w * r0.z;
  r0.z = max(0, r0.z);
  r0.z = min(1, r0.z);
  r0.w = -2 * r0.z;
  r0.w = 3 + r0.w;
  r0.z = r0.z * r0.z;
  r0.z = r0.w * r0.z;
  r0.y = r0.z * r0.y;
  r0.y = max(0, r0.y);
  r0.y = min(1, r0.y);
  r0.x = r0.x * r0.y;
  r0.y = -g_psObject.m_localParam[2].x;
  r0.y = r5.z + r0.y;
  r0.y = g_psObject.m_localParam[2].y * r0.y;
  r0.y = max(0, r0.y);
  r0.y = min(1, r0.y);
  r0.y = -r0.y;
  r0.y = 1 + r0.y;
  r0.y = r0.y * r0.y;
  r0.x = r0.x * r0.y;
  r0.x = r0.x;
  r0.x = r0.x;
  r0.x = r0.x;
  r0.y = g_psLight.m_lightParams[7].x;
  r0.y = max(r0.y, r0.x);
  r0.y = r0.y;
  r2.xyz = r2.xyz;
  r6.xyz = r6.xyz;
  r7.xyzw = r7.xyzw;
  r1.xzw = r1.xzw;
  r3.x = r3.x;
  r3.z = r3.z;
  r1.y = r1.y;
  r3.w = r3.w;
  r2.xyz = r2.xyz;
  r6.xyz = r6.xyz;
  r7.xyzw = r7.xyzw;
  r1.xzw = r1.xzw;
  r3.x = r3.x;
  r3.z = r3.z;
  r1.y = r1.y;
  r3.w = r3.w;
  r6.xyz = r6.xyz;
  r1.xzw = r1.xzw;
  r2.xyz = r2.xyz;
  r4.xyz = r6.xyz;
  r0.z = dot(r4.xyz, r2.xyz);
  r5.xyz = -r1.xzw;
  r0.w = dot(r5.xyz, r2.xyz);
  r0.w = r0.w + r0.w;
  r0.w = -r0.w;
  r8.xyz = r2.xyz * r0.www;
  r8.xyz = r8.xyz + r5.xyz;
  r8.xyz = -r8.xyz;
  r9.xyz = -r4.xyz;
  r9.xyz = r9.xyz + r8.xyz;
  r0.w = dot(r9.xyz, r9.xyz);
  r0.w = sqrt(r0.w);
  r0.w = r7.w / r0.w;
  r0.w = max(0, r0.w);
  r9.xyz = min(float3(1,1,1), r0.www);
  r10.xyz = -r6.xyz;
  r8.xyz = r10.xyz + r8.xyz;
  r8.xyz = r9.xyz * r8.xyz;
  r6.xyz = r8.xyz + r6.xyz;
  r0.w = dot(r6.xyz, r6.xyz);
  r0.w = rsqrt(r0.w);
  r6.xyz = r6.xyz * r0.www;
  r5.xyz = r6.xyz + r5.xyz;
  r0.w = dot(r5.xyz, r5.xyz);
  r0.w = rsqrt(r0.w);
  r5.xyz = r5.xyz * r0.www;
  r0.w = dot(r5.xyz, r2.xyz);
  r0.w = max(0, r0.w);
  r0.w = min(1, r0.w);
  r4.x = dot(r5.xyz, r4.xyz);
  r3.z = r3.z;
  r3.y = 0.25;
  r5.xyzw = g_MaterialTexture.Sample(g_samplerPoint_Clamp_s, r3.zy).xyzw;
  r3.y = 0.75;
  r6.xz = g_MaterialTexture.Sample(g_samplerPoint_Clamp_s, r3.zy).xw;
  r6.xz = r6.xz;
  r5.xyz = r5.xyz;
  r5.w = r5.w;
  r2.w = r6.x;
  r6.z = r6.z;
  r4.x = r4.x;
  r4.y = r2.w;
  r3.y = g_lut1.Sample(g_samplerLinear_Clamp_s, r4.xy).x;
  r3.y = r3.y;
  r3.y = r3.y;
  r3.z = r0.z * r0.z;
  r3.z = -r3.z;
  r3.z = 1 + r3.z;
  r3.z = r3.z * r3.w;
  r3.z = r3.z + r0.z;
  r3.w = r5.w * r3.w;
  r3.z = max(r3.z, r3.w);
  r3.z = max(0, r3.z);
  r3.z = min(1, r3.z);
  r4.xyz = r5.xyz * r3.xxx;
  r0.w = r0.w;
  r1.y = r1.y;
  r6.z = r6.z;
  r0.w = max(0, r0.w);
  r6.x = min(1, r0.w);
  r6.y = r1.y;
  r6.z = r6.z;
  r6.xyz = r6.xyz * r6.xyz;
  r6.xyz = float3(0.984375,0.9375,0.9375) * r6.xyz;
  r6.xyz = float3(0.0078125,0.03125,0.03125) + r6.xyz;
  r6.xy = g_lut2.Sample(g_samplerLinear_Clamp_s, r6.xyz).xy;
  r6.xy = r6.xy;
  r6.xy = r6.xy * r6.xy;
  r0.w = r6.x / r6.y;
  r0.w = r3.y * r0.w;
  r0.z = r0.z;
  r0.z = 4 * r0.z;
  r0.z = max(0, r0.z);
  r0.z = min(1, r0.z);
  r0.z = r0.w * r0.z;
  r4.xyz = r4.xyz * r7.xyz;
  r4.xyz = r4.xyz * r0.zzz;
  r0.z = 1 * r3.z;
  r0.z = 1 * r0.z;
  r3.yzw = r0.zzz * r7.xyz;
  r4.xyz = r4.xyz;
  r3.yzw = r3.yzw;
  r0.z = dot(r1.xzw, r2.xyz);
  r0.z = r0.z + r0.z;
  r0.z = -r0.z;
  r6.xyz = r2.xyz * r0.zzz;
  r6.xyz = r6.xyz + r1.xzw;
  r1.xzw = -r1.xzw;
  r0.z = dot(r1.xzw, r2.xyz);
  r0.z = max(0, r0.z);
  r2.x = min(1, r0.z);
  r2.y = max(g_psLight.m_lightParams[2].z, r2.w);
  r0.z = g_lut1.Sample(g_samplerLinear_Clamp_s, r2.xy).x;
  r0.z = r0.z;
  r0.z = r0.z;
  r1.xz = -r6.xy;
  r1.xz = r1.xz;
  r1.xz = float2(0.96875,0.96875) * r1.xz;
  r1.xz = float2(0.5,0.5) * r1.xz;
  r1.xz = float2(0.5,0.5) + r1.xz;
  r1.xz = float2(0.25,0.125) * r1.xz;
  r1.xz = r1.xz;
  r0.w = cmp(0 < r6.z);
  r2.xy = r0.ww ? float2(0.25,0) : float2(0,0);
  r1.xz = r2.xy + r1.xz;
  r1.xz = g_SkyReflectTexture.Sample(g_samplerLinear_Clamp_s, r1.xz).xy;
  r1.xz = float2(4,4) * r1.xz;
  r0.w = 1.42799997 * r1.y;
  r0.w = -0.300000012 + r0.w;
  r0.w = max(0, r0.w);
  r0.w = min(1, r0.w);
  r1.w = -r1.x;
  r1.z = r1.z + r1.w;
  r0.w = r1.z * r0.w;
  r1.xzw = r1.xxx + r0.www;
  r2.xyz = g_psLight.m_lightParams[3].xyz;
  r1.xzw = r2.xyz * r1.xzw;
  r0.w = -r1.y;
  r0.w = 1 + r0.w;
  r0.w = 0.5 * r0.w;
  r0.z = r0.w * r0.z;
  r0.z = r0.z * r3.x;
  r1.xyz = r1.xzw * r0.zzz;
  r1.xyz = r1.xyz * r5.xyz;
  r3.yzw = r3.yzw;
  r4.xyz = r4.xyz;
  r1.xyz = r1.xyz;
  r3.yzw = r3.yzw;
  r4.xyz = r4.xyz;
  r0.y = r0.y;
  r3.yzw = r3.yzw;
  r4.xyz = r4.xyz;
  r0.y = r0.y;
  r2.xyz = r3.yzw * r0.xxx;
  r2.xyz = float3(1,1,1) * r2.xyz;
  r0.yzw = r4.xyz * r0.yyy;
  r0.yzw = float3(1,1,1) * r0.yzw;
  r2.xyz = r2.xyz;
  r0.yzw = r0.yzw;
  r2.xyz = r2.xyz;
  r0.yzw = r0.yzw;
  r1.xyz = r1.xyz;
  r2.xyz = r2.xyz;
  r0.yzw = r0.yzw;
  r1.xyz = r1.xyz;
  r0.x = max(g_psLight.m_lightParams[2].x, r0.x);
  r0.x = g_psLight.m_lightParams[2].y * r0.x;
  r2.xyz = float3(-0,-0,-0) + r2.xyz;
  r1.xyz = r1.xyz * r0.xxx;
  r0.xyz = r1.xyz + r0.yzw;
  r2.xyz = r2.xyz;
  r0.xyz = r0.xyz;
  r0.xyz = r0.xyz;
  r0.xyz = r0.xyz;
  r0.xyz = r0.xyz;
  r0.w = 1;
  r0.xyz = r0.xyz;
  r0.xyzw = r0.xyzw;
  r0.xyzw = r0.xyzw;
  r2.xyz = r2.xyz;
  r2.xyz = r2.xyz;
  r2.xyz = r2.xyz;
  r2.w = 1;
  r2.xyz = r2.xyz;
  r2.xyzw = r2.xyzw;
  r2.xyzw = r2.xyzw;
  o0.xyzw = r2.xyzw;
  o1.xyzw = r0.xyzw;
  return;
}
