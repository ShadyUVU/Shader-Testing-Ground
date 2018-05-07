// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/FirstLight"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        // _MainTex is the standard for the main texture. Allows access to Material.mainTexture property.
        _MainTex ("Albedo", 2D) = "white" {}
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
    }
    
	SubShader
	{
	    Pass
	    {
	        Tags
	        {
	            // This tag sets forward rendering and allows us to use directional lights in our shader.
	            "LightMode" = "ForwardBase"
	        }
	        
	        CGPROGRAM
	        
	        #pragma target 5.0
	        
	        #pragma vertex MyVertexProgram
	        #pragma fragment MyFragmentProgram
	        
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
	        
	        struct Interpolaters
	        {
	            float4 position : SV_POSITION;
	            float2 uv : TEXCOORD0;
	            float3 normal : TEXCOORD1;
	            float3 worldPos : TEXCOORD2;
	        };
	        
	        struct VertexData
	        {
	            float4 position : POSITION;
	            float3 normal : NORMAL;
	            float2 uv : TEXCOORD0;
	        };

	        // Input: position: The correct vertex position. POSITION is the object-space position of the vertex.
	        // Output: localPosition, provides local vertex position to fragment shader for interpolation.
	        // SV_POSITION indicates we're trying to output the position of a vertex.
	        Interpolaters MyVertexProgram (VertexData v)
	        {
	            Interpolaters i;
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
	            return i;
	        }
	        
	        // We input a float4 SV_POSITION to match the output of the vertex program.
	        // SV_TARGET is the default shader target, where the final color should be written to.
	        float4 MyFragmentProgram (Interpolaters i) : SV_TARGET 
	        {
	            i.normal = normalize(i.normal);
	            // _WorldSpaceLightPos0 gets us the position of the main light.
	            float3 lightDir = _WorldSpaceLightPos0.xyz;
	            float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
	            // _LightColor0 is the color of the main light.
	            float3 lightColor = _LightColor0.rgb;
	            float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
	            float3 specularTint;
	            float oneMinusReflectivity;
	            albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);
	            
	            UnityLight light;
	            light.color = lightColor;
	            light.dir = lightDir;
	            light.ndotl = DotClamped(i.normal, lightDir);
	            UnityIndirect indirectLight;
	            indirectLight.diffuse = 0;
	            indirectLight.specular = 0;
	           
	            // Multiply by _Tint to factor in its color.
	            // Add 0.5 because to eiminate black because negative numbers get clamped to zero (black).
	            // saturate clamps between 0 and 1. (return saturate(dot(float3(0, 1, 0), i.normal));)
	            // DotClamped performs dot products and never produces negative numbers to begin with.
	            return UNITY_BRDF_PBS(albedo, specularTint, oneMinusReflectivity, _Smoothness, i.normal, viewDir, light, indirectLight);
	        }
	        ENDCG
	    }
	}
}

