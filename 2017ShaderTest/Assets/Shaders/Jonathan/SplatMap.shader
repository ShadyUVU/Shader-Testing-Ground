// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/SplatMap"
{
    Properties
    {
        // _MainTex is the standard for the main texture. Allows access to Material.mainTexture property.
        _MainTex ("Splat Map", 2D) = "white" {}
        [NoScaleOffset] _Texture1 ("Texture1", 2D) = "white" {}
        [NoScaleOffset] _Texture2 ("Texture2", 2D) = "white" {}
        [NoScaleOffset] _Texture3 ("Texture3", 2D) = "white" {}
        [NoScaleOffset] _Texture4 ("Texture4", 2D) = "white" {}
    }
    
	SubShader
	{
	    Pass
	    {
	        CGPROGRAM
	        
	        #pragma vertex MyVertexProgram
	        #pragma fragment MyFragmentProgram
	        
	        // Includes some essential files, contains some generic functionality.
	        #include "UnityCG.cginc"
	        
	        // The names of variables must exactly match those in the Properties section.
	        sampler2D _MainTex;
	        // Extra texture data is stored here. Allows for tiling and scaling and stuff.
	        float4 _MainTex_ST;
	        
	        sampler2D _Texture1, _Texture2, _Texture3, _Texture4;
	        
	        struct Interpolaters
	        {
	            float4 position: SV_POSITION;
	            float2 uv: TEXCOORD0;
	            float2 uvSplat : TEXCOORD1;
	        };
	        
	        struct VertexData
	        {
	            float4 position: POSITION;
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
	            // Multiplying by _MainTex_ST.xy allows for tiling.
	            // Adding _MainTex_ST.zw allows for offset.
	            // i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
	            i.uv = TRANSFORM_TEX(v.uv, _MainTex); // Macro for the above command. Included in UnityCG.cginc.
	            i.uvSplat = v.uv;
	            return i;
	        }
	        
	        // We input a float4 SV_POSITION to match the output of the vertex program.
	        // SV_TARGET is the default shader target, where the final color should be written to.
	        float4 MyFragmentProgram (Interpolaters i) : SV_TARGET 
	        {
	            float4 splat = tex2D (_MainTex, i.uvSplat);
	            // Multiply by _Tint to factor in its color.
	            // Add 0.5 because to eiminate black because negative numbers get clamped to zero (black).
	            return 
	                tex2D(_Texture1, i.uv) * splat.r +
	                tex2D(_Texture3, i.uv) * splat.b +
	                tex2D(_Texture4, i.uv) * splat.g +
	                tex2D(_Texture2, i.uv) * (1 - splat.r - splat.b - splat.g);
	        }
	        ENDCG
	    }
	}
}

