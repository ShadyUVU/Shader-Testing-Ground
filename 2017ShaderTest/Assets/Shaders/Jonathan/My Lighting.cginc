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
sampler2D _MainTex;
// Extra texture data is stored here. Allows for tiling and scaling and stuff.
float4 _MainTex_ST;
float _Metallic;
float _Smoothness;

struct Interpolators
{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    
    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD3;
    #endif
};

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
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
    // Multiplying by _MainTex_ST.xy allows for tiling.
    // Adding _MainTex_ST.zw allows for offset.
    // i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    i.uv = TRANSFORM_TEX(v.uv, _MainTex); // Macro for the above command. Included in UnityCG.cginc.
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
    return indirectLight;
}    

// We input a float4 SV_POSITION to match the output of the vertex program.
// SV_TARGET is the default shader target, where the final color should be written to.
float4 MyFragmentProgram (Interpolators i) : SV_TARGET 
{
    i.normal = normalize(i.normal);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);
	float3 shColor = ShadeSH9(float4(i.normal, 1));
	return float4(shColor, 1);
	   
    // Multiply by _Tint to factor in its color.
    // Add 0.5 because to eiminate black because negative numbers get clamped to zero (black).
    // saturate clamps between 0 and 1. (return saturate(dot(float3(0, 1, 0), i.normal));)
    // DotClamped performs dot products and never produces negative numbers to begin with.
    return UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, _Smoothness, i.normal, viewDir, CreateLight(i), CreateIndirectLight(i));
}

#endif