﻿Shader "Unlit/Bumpiness"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        // _MainTex is the standard for the main texture. Allows access to Material.mainTexture property.
        _MainTex ("Albedo", 2D) = "white" {}
        [NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _DetailTex ("Detail Texture", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
        _DetailBumpScale ("Detail Bump Scale", Float) = 1
    }
    
    CGINCLUDE
    #define BINORMAL_PER_FRAGMENT
    ENDCG
    
    SubShader
    {
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            
            CGPROGRAM
            
            #pragma target 5.0
            
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            #pragma multi_compile_VERTEXLIGHT_ON
            
            #define FORWARD_BASE_PASS
            
            #include "My Lighting.cginc"

            ENDCG
        }
        
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
            }
                        
            Blend One One
            ZWrite Off
            
            CGPROGRAM
            
            #pragma target 5.0
            
            #pragma multi_compile_fwdadd
            
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            #include "My Lighting.cginc"

            ENDCG
        }
    }
}
