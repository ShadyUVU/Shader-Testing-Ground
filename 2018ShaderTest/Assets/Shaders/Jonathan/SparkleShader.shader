Shader "Unlit/SparkleShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
			
		_NoiseTex ("Noise Texture", 2D) = "white" {}
		_Scale ("Scale", Float) = 1
		_Intensity ("Intensity", Float) = 50
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			//#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				
				float3 normal:NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				//UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
				
				float3 wPos:TEXCOORD1;
				float3 wNormal:TEXCOORD2;
			};
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			sampler2D _NoiseTex;
			
			float _Scale;
			float _Intensity;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				//UNITY_TRANSFER_FOG(o,o.vertex);
				
				o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				o.wNormal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);
				// apply fog
				//UNITY_APPLY_FOG(i.fogCoord, col);

				
				fixed3 sparklemap = tex2D(_NoiseTex, i.uv * _Scale);
				sparklemap -= half3(0.5,0.5,0.5);
				sparklemap = normalize(normalize(sparklemap) + i.wNormal);
				
				half3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);
				half sparkle = dot(-viewDirection, sparklemap);
				sparkle = pow(saturate(sparkle), _Intensity);
				col += half4(sparkle, sparkle, sparkle, 0);
				
				return col;
			}
			ENDCG
		}
	}
}
