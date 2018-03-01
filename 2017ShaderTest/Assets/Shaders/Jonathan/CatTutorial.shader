// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/CatTutorial"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)
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
	        float4 _Tint;
	        
	        // Input: position: The correct vertex position. POSITION is the object-space position of the vertex.
	        // Output: localPosition, provides local vertex position to fragment shader for interpolation.
	        // SV_POSITION indicates we're trying to output the position of a vertex.
	        float4 MyVertexProgram (float4 position: POSITION, out float3 localPosition: TEXCOORD0) : SV_POSITION 
	        {
	            // Copying the x, y, and z components from  position to localPosition.
	            localPosition = position.xyz;
	            // Multiply the model-view-projection matrix with the vertex object space positions.
	            return UnityObjectToClipPos(position);
	        }
	        
	        // We input a float4 SV_POSITION to match the output of the vertex program.
	        // SV_TARGET is the default shader target, where the final color should be written to.
	        float4 MyFragmentProgram (float4 position : SV_POSITION, float3 localPosition : TEXCOORD0) : SV_TARGET 
	        {
	            // return _Tint;
	            return float4(localPosition, 1);
	        }
	        ENDCG
	    }
	}
}
