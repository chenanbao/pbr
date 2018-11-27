Shader "PBRShader"
{
	Properties
	{
		_Color ("Main Color", Color) = (1,1,1,1)
		_Albedo ("Albedo", 2D) = "white" {}
	

		_Roughness("Roughness",Range(0,1)) = 1
		_Metalness("Metallicness",Range(0,1)) = 0
	}
	SubShader
	{
		
		LOD 100

		Pass
		{
			Name "FORWARD"
            Tags { 
				"RenderType"="Opaque"
				"LightMode" = "ForwardBase"
			}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
          
			struct VertexInput
			{
				float4 vertex : POSITION;       //local vertex position
				float3 normal : NORMAL;         //normal direction
				float4 tangent : TANGENT;       //tangent direction    
				float2 texcoord0 : TEXCOORD0;   //uv coordinates
			};

			struct VertexOutput
			{
				float4 pos : SV_POSITION;              //screen clip space position and depth
				float2 uv0 : TEXCOORD0;                //uv coordinates
				float3 normalDir : TEXCOORD3;          //normal direction   
				float3 posWorld : TEXCOORD4;          //normal direction   
				float3 tangentDir : TEXCOORD5;
				float3 bitangentDir : TEXCOORD6;
			};

			uniform fixed4 _LightColor0;
			sampler2D _Albedo;fixed4 _Albedo_ST;
			float4 _Color;
	
			float _Roughness;
			float _Metalness;
			
			VertexOutput vert (VertexInput v) {
				VertexOutput o ;           
				o.uv0 = TRANSFORM_TEX(v.texcoord0, _Albedo);
				o.normalDir = UnityObjectToWorldNormal(v.normal);
				o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
				o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				
				return o;
			}


			float3 SchlickFresnelFunction(float NdotV,float3 F0){
    			return F0 + (1 - F0)* pow(1.0-NdotV,5.0);
			}

			
			fixed GeometrySmith(float NdotL, float NdotV, fixed roughness)
			{
				fixed r = (roughness + 1.0);
			    fixed k = (r*r) / 8.0;	

			    fixed ggx2  = NdotV / (NdotV * (1.0 - k) + k);
			    fixed ggx1  = NdotL / (NdotL * (1.0 - k) + k);

			    return ggx1 * ggx2;
			}


			fixed GGXNormalDistribution(fixed roughness, float NdotH)
			{
			    fixed a      = roughness*roughness;
			    fixed a2     = a*a;
			    fixed denom = ( NdotH*NdotH * (a2 - 1.0) + 1.0);
			  
			    return  a2 / (UNITY_PI * denom * denom);
			}


		fixed4 frag(VertexOutput i) : SV_Target {

			//normal direction calculations
			float3 normalDirection = normalize(i.normalDir);
			float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);
			
			//light calculations
			float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
			float3 lightReflectDirection = reflect( -lightDirection, normalDirection );
			float3 viewReflectDirection = normalize(reflect( -viewDirection, normalDirection ));
			float NdotL = max(0.0, dot( normalDirection, lightDirection ));
			float3 halfDirection = normalize(viewDirection+lightDirection); 
			float NdotH =  max(0.0,dot( normalDirection, halfDirection));
			float NdotV =  max(0.0,dot( normalDirection, viewDirection));
			float VdotH = max(0.0,dot( viewDirection, halfDirection));
			float LdotH =  max(0.0,dot(lightDirection, halfDirection)); 
			float LdotV = max(0.0,dot(lightDirection, viewDirection)); 
			float RdotV = max(0.0, dot( lightReflectDirection, viewDirection ));

			fixed4 albedo = tex2D(_Albedo, i.uv0)*_Color;//采样固有色贴图

			fixed3 F0 = lerp(fixed3(0.04,0.04,0.04), albedo, _Metalness);//金属与非金属的区别
			fixed3 fresnel  = SchlickFresnelFunction(NdotV, F0);//菲涅尔项

			fixed NDF = GGXNormalDistribution(_Roughness,NdotH);//Cook-Torrance 的d项

			fixed G = GeometrySmith(NdotL, NdotV, _Roughness);//Cook-Torrance 的g项

			fixed3 specular = NDF * G * fresnel / (4.0 * NdotV * NdotL + 0.001);//反射部分 ps：+0.001是为了防止除零错误

			fixed3 kD = (1.0 - fresnel) * (1.0 - _Metalness);//diffuse部分系数

			float3 finalColor = (kD * albedo + specular) *  _LightColor0.xyz * NdotL;

			return  float4(finalColor,1.0);

		 }
			ENDCG
		}
	}
}
