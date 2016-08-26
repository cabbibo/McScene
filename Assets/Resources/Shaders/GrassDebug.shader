Shader "Custom/GrassDebug" {

		Properties {
			_MainTex ("Albedo (RGB)", 2D) = "white" {}
		}

    SubShader{
//        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        Cull off
        Pass{

            Blend SrcAlpha OneMinusSrcAlpha // Alpha blending
 
            CGPROGRAM
            #pragma target 5.0
 
            #pragma vertex vert
            #pragma fragment frag
 
            #include "UnityCG.cginc"
 
 						struct Vert{
							float3 pos; 
							float3 vel;
							float3 nor;
							float2 uv;
							float2 texUV;
							float  bladeID;
							float  downID;
							float  upID;
							float3 debug;
						};

            StructuredBuffer<Vert> vertBuffer;

            uniform int _BladeLength;
            uniform sampler2D _MainTex;



 
            //A simple input struct for our pixel shader step containing a position.
            struct varyings {
                float4 pos      : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 nor      : TEXCOORD0;
                float3 eye      : TEXCOORD2;
                float3 debug    : TEXCOORD3;
                float2 uv       : TEXCOORD4;
                float3 col      : TEXCOORD5;
            };


            //Our vertex function simply fetches a point from the buffer corresponding to the vertex index
            //which we transform with the view-projection matrix before passing to the pixel program.
            varyings vert (uint id : SV_VertexID){

                varyings o;

                float baseID =floor(float(id)/2);
                float bladeID = floor(baseID / (float(_BladeLength)-1));
                float bladeRow = baseID - bladeID * float(_BladeLength-1);
                uint fID = uint( bladeID*_BladeLength + bladeRow ) + uint(float( id ) % 2);

                Vert v = vertBuffer[fID];


                o.worldPos = v.pos;

                o.pos = mul (UNITY_MATRIX_VP, float4(o.worldPos,1.0f));
                o.debug = v.debug;// * nor;//o.worldPos - og.pos;

                o.col = tex2Dlod( _MainTex , float4(v.texUV.x , v.texUV.y,0,0)).xyz;

                o.eye = _WorldSpaceCameraPos - o.worldPos;
                o.uv = v.uv;
                o.nor = v.nor;
                return o;

            }
 
            //Pixel function returns a solid color for each point.
            float4 frag (varyings v) : COLOR {
            		float3 fCol = v.debug * v.uv.y + v.col * (1-v.uv.y);
                return float4( fCol , 1.);
            }
 
            ENDCG
 
        }
    }
 
    Fallback Off
	
}
