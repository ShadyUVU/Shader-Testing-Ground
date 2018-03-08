// This pre-processory if-block prevents code duplication when included in shaders.
#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

// Macro that inserts code to compute the correct attenuation factor.
#include "AutoLight.cginc"
// Includes some essential files, contains some generic functionality.
// #include "UnityCG.cginc" (included in UnityStandardBRDF)
#include "UnityPBSLighting.cginc"

// The names of variables must exactly match those in the Properties section.
float4 _Tint;
sampler2D _MainTex, _DetailTex;;
// Extra texture data is stored here. Allows for tiling and scaling and stuff.
float4 _MainTex_ST, _DetailTex_ST;

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

float _Metallic;
float _Smoothness;

struct Interpolators
{
    float4 position : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    
    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif
        
    float3 worldPos : TEXCOORD4;
    
    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD5;
    #endif
};

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

void ComputeVertexLightColor (inout Interpolators i)
{
    #if defined(VERTEXLIGHT_ON)
		i.vertexLightColor = Shade4PointLights
		(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos, i.normal
		);
    #endif
}

// Putting the binormal calculation out here so we can use it in either our vertex or fragment shader.
float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
	return cross(normal, tangent.xyz) *
		(binormalSign * unity_WorldTransformParams.w);
}

// Input: position: The correct vertex position. POSITION is the object-space position of the vertex.
// Output: localPosition, provides local vertex position to fragment shader for interpolation.
// SV_POSITION indicates we're trying to output the position of a vertex.
Interpolators MyVertexProgram (VertexData v)
{
    Interpolators i;
    // Multiply the model-view-projection matrix with the vertex object space positions.
    i.position = UnityObjectToClipPos(v.position);
    // World position of the surface
    i.worldPos = mul (unity_ObjectToWorld, v.position);
    // Change normals from object space to world space.
    i.normal = UnityObjectToWorldNormal(v.normal);
    
	#if defined(BINORMAL_PER_FRAGMENT)
		i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
	#else
		i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
		i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
	#endif
	
    // Multiplying by _MainTex_ST.xy allows for tiling.
    // Adding _MainTex_ST.zw allows for offset.
    // i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex); // Macro for the above command. Included in UnityCG.cginc.
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    ComputeVertexLightColor(i);
    return i;
}

UnityLight CreateLight (Interpolators i)
{
    UnityLight light;
    // _WorldSpaceLightPos0 gets us the position of the main light.
    // Subtracting the object position gives us the direction of the light, in case of point lights and such.
    #if defined(POINT) || defined (POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    
    UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
    // _LightColor0 is the color of the main light.
    light.color = _LightColor0.rgb * attenuation;
    light.ndotl = DotClamped(i.normal, light.dir);
    return light;
}

UnityIndirect CreateIndirectLight (Interpolators i)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;
    
    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif
    
    // Add spherical harmonics data, clamped to never be negative.
    #if defined(FORWARD_BASE_PASS)
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1))); 
    #endif
    
    return indirectLight;
}    

void InitializeFragmentNormal (inout Interpolators i)
{
    float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    
    float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);
	
	#if defined(BINORMAL_PER_FRAGMENT)
		float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
	#else
		float3 binormal = i.binormal;
	#endif
	
	i.normal = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);
}

// We input a float4 SV_POSITION to match the output of the vertex program.
// SV_TARGET is the default shader target, where the final color should be written to.
float4 MyFragmentProgram (Interpolators i) : SV_TARGET 
{
    InitializeFragmentNormal(i);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);

    // Multiply by _Tint to factor in its color.
    // Add 0.5 because to eiminate black because negative numbers get clamped to zero (black).
    // saturate clamps between 0 and 1. (return saturate(dot(float3(0, 1, 0), i.normal));)
    // DotClamped performs dot products and never produces negative numbers to begin with.
    return UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, _Smoothness, i.normal, viewDir, CreateLight(i), CreateIndirectLight(i));
}

#endif