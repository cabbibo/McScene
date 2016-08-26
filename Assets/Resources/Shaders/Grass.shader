Shader "Custom/Grass" {

		Properties {
			_MainTex   ("baseTexture", 2D) = "white" {}
			_TextureMap ("bladeTexture", 2D) = "white" {}
			_NormalMap ("normal", 2D) = "white" {}
			_CubeMap ("cube", Cube) = "white" {}
		}

    SubShader{
//        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        Cull Off
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
            uniform float4x4 worldMat;
            uniform float4x4 invWorldMat;

            uniform int _BladeWidth;
            uniform int _BladeLength;
            uniform int _BladeResolution;
            uniform int _TotalVerts;

            uniform sampler2D _MainTex;
            uniform sampler2D _NormalMap;
            uniform sampler2D _TextureMap;
            uniform samplerCUBE _CubeMap;

						float3 uvNormalMap( sampler2D normalMap , float3 pos , float2 uv , float3 norm , float texScale , float normalScale ){
             
             	float3 q0 = ddx( pos.xyz );
              float3 q1 = ddy( pos.xyz );
              float2 st0 = ddx( uv.xy );
              float2 st1 = ddy( uv.xy );

              float3 S = normalize(  q0 * st1.y - q1 * st0.y );
              float3 T = normalize( -q0 * st1.x + q1 * st0.x );
              float3 N = normalize( norm );

              float3 mapN = tex2D( normalMap, uv*texScale ).xyz * 2.0 - 1.0;
              mapN.xy = normalScale * mapN.xy;
             
              float3x3 tsn = transpose( float3x3( S, T, N ) );
              float3 fNorm =  normalize( mul(tsn , mapN) ); 

              return fNorm;

            }



 
            //A simple input struct for our pixel shader step containing a position.
            struct varyings {
                float4 pos      : SV_POSITION;
                float3 worldPos : TEXCOORD1;
                float3 nor      : TEXCOORD0;
                float3 eye      : TEXCOORD2;
                float3 debug    : TEXCOORD3;
                float3 col 			: TEXCOORD5;
                float2 uv       : TEXCOORD4;
            };

					

						float3 cubicCurve( float t , float3  c0 , float3 c1 , float3 c2 , float3 c3 ){
						  
						  float s  = 1. - t; 

						  float3 v1 = c0 * ( s * s * s );
						  float3 v2 = 3. * c1 * ( s * s ) * t;
						  float3 v3 = 3. * c2 * s * ( t * t );
						  float3 v4 = c3 * ( t * t * t );

						  float3 value = v1 + v2 + v3 + v4;

						  return value;

						}

            float3 cubicFromValue( in float val , in float bladeID , out float3 upPos , out float3 doPos ){

						  //float3 upPos;
						  //float3 doPos;


						  float3 p0 = float3( 0. , 0. , 0. );
						  float3 v0 = float3( 0. , 0. , 0. );
						  float3 p1 = float3( 0. , 0. , 0. );
						  float3 v1 = float3( 0. , 0. , 0. );

						  float3 p2 = float3( 0. , 0. , 0. );



						  float base = val * (float(_BladeLength)-1.);
						  float baseUp   = floor( base );
						  float baseDown = ceil( base );
						  float amount = base - baseUp;

						  int bladeBase = _BladeLength * int( bladeID );

						  if( baseUp == 0. ){

						      p0 = vertBuffer[ int( baseUp )        + bladeBase ].pos;
						      p1 = vertBuffer[ int( baseDown )      + bladeBase ].pos;
						      p2 = vertBuffer[ int( baseDown + 1. ) + bladeBase ].pos;


						      v1 = .5 * ( p2 - p0 );

						  }else if( baseDown == float(_BladeLength-1) ){

						      p0 = vertBuffer[ int( baseUp )      + bladeBase ].pos;
						      p1 = vertBuffer[ int( baseDown )    + bladeBase ].pos;
						      p2 = vertBuffer[ int( baseUp - 1. ) + bladeBase ].pos;

						      v0 = .5 * ( p1 - p2 );

						  }else{

						      p0 = vertBuffer[ int( baseUp )   + bladeBase ].pos;
						      p1 = vertBuffer[ int( baseDown ) + bladeBase ].pos;


						      float3 pMinus;

						      pMinus = vertBuffer[ int( baseUp - 1. )   + bladeBase ].pos;
						      p2 =     vertBuffer[ int( baseDown + 1. ) + bladeBase ].pos;

						      v1 = .5 * ( p2 - p0 );
						      v0 = .5 * ( p1 - pMinus );

						  }


						  float3 c0 = p0;
						  float3 c1 = p0 + v0/3.;
						  float3 c2 = p1 - v1/3.;
						  float3 c3 = p1;




						  float3 pos = cubicCurve( amount , c0 , c1 , c2 , c3 );

						  upPos = cubicCurve( amount  + .1 , c0 , c1 , c2 , c3 );
						  doPos = cubicCurve( amount  - .1 , c0 , c1 , c2 , c3 );

						  return pos;


						}

						float3 straightFromVal( in float val , in float bladeID , out float3 upPos , out float3 doPos ){


						}


            //Our vertex function simply fetches a point from the buffer corresponding to the vertex index
            //which we transform with the view-projection matrix before passing to the pixel program.
            varyings vert (uint id : SV_VertexID){

                varyings o;


                float bID = floor( id / 6 );//floor(float((float(id) / (3*2))));// / float( _BladeWidth * _BladeResolution-1 );
                float idInTri = fmod( float(id) , 3 );
                float idInTri2 = fmod( floor(float(id)/3) , 2 );
                uint tri  = id % 6;

               // bID /= 3*2;
                //bID = floor( bID );

                // from getRibbonID 
                float bladeID = floor( id / ((_BladeWidth * (_BladeResolution-1)) * 3 * 2));
                float remainID = id - bladeID * (_BladeWidth * (_BladeResolution-1) * 3 * 2);
                float row = floor(remainID / (_BladeWidth * 3 * 2));
                float triID = floor( id / 6 );
                
                float col = triID  % _BladeWidth;
                float colU = (triID +1 ) % _BladeWidth;



                


                float3 upPos; float3 doPos;

                float r1 = row / float(_BladeResolution);
                float r2 = (row+1) / float(_BladeResolution);

                float3 pos1 = cubicFromValue( r1 , bladeID , upPos , doPos );
                float3 nor1 = normalize( upPos - doPos );

                float3 pos2 = cubicFromValue( r2 , bladeID , upPos , doPos );
                float3 nor2 = normalize( upPos - doPos ); 



                float3 x1 = normalize( cross( nor1 , float3( 1, 0 , 0)));
                float3 z1 = normalize( cross( nor1 , x1 ));

                float3 x2 = normalize( cross( nor2 , float3( 1, 0 , 0)));
                float3 z2 = normalize( cross( nor2 , x2 ));

								float angle =  col/_BladeWidth * 2 * 3.14159;
              	float angleU = (col+1)/_BladeWidth * 2 * 3.14159;


              	float radius = .04f * pow((1 - r1),.5);
              	float radiusU = .04f * pow((1 - r2),.5);

              	float3 f1 = radius * sin(angle ) * x1   + radius * cos( angle  ) * z1 + pos1;
              	float3 f2 = radius * sin(angleU) * x1   + radius * cos( angleU ) * z1 + pos1;
              	float3 f3 = radiusU * sin(angle ) * x2   + radiusU * cos( angle  ) * z2 + pos2;
              	float3 f4 = radiusU * sin(angleU) * x2   + radiusU * cos( angleU ) * z2 + pos2;

              	float3 n1 = normalize(f1 - pos1);
              	float3 n2 = normalize(f2 - pos1);
              	float3 n3 = normalize(f3 - pos2);
              	float3 n4 = normalize(f4 - pos2);

              	float2 uv1 = float2(r1,(col)/_BladeWidth);
              	float2 uv2 = float2(r1,(col+1)/_BladeWidth);
              	float2 uv3 = float2(r2,(col)/_BladeWidth);
								float2 uv4 = float2(r2,(col+1)/_BladeWidth);


              	float3 finalPos; float3 finalNor; float2 finalUV;


              	//f1 = float3( bladeID , 0 + row , 0 );
              	//f2 = float3( bladeID , 0 + row , 1 );
              	//f3 = float3( bladeID , 1 + row , 0 );
              	//f4 = float3( bladeID , 1 + row , 1 );

              	//f1 = float3( 0 , 0 , 0 );
              	//f2 = float3( 1 , 0 , 0 );
              	//f3 = float3( 0 , 1 , 0 );
              	//f4 = float3( 1 , 1 , 0 );

 	             	if( tri == 0){
 	             		finalPos = f1;
 	             		finalNor = n1;
 	             		finalUV = uv1;

              	}else if( tri == 1 ){
              		finalPos = f2;
 	             		finalNor = n2;
 	             		finalUV = uv2;
              	}else if( tri == 2 ){
              		finalPos = f4;
 	             		finalNor = n4;
 	             		finalUV = uv4;
              	}else if( tri == 3 ){
              		finalPos = f1;
 	             		finalNor = n1;
 	             		finalUV = uv1;
              	}else if( tri == 4 ){
              		finalPos = f4;
 	             		finalNor = n4;
 	             		finalUV = uv4;
              	}else if( tri == 5 ){
              		finalPos = f3;
 	             		finalNor = n3;
 	             		finalUV = uv3;
              	}else{}





								int bladeBase = _BladeLength * int( bladeID );
								Vert baseVert = vertBuffer[ bladeBase ];
								o.col = tex2Dlod( _MainTex , float4(baseVert.texUV.x , baseVert.texUV.y,0,0)).xyz;
              // Vert v = vertBuffer[fID];
              // Vert vUp = vertBuffer[v.upID];

              // float3 up = normalize(vUp.pos - v.pos);
              // float3 cPos = v.pos;
              // float3 uPos = 
              // float3 left = normalize(cross( up , float3(1,0,0)));
              // float3 forward = normalize( cross(left,up));

              

              float3 fPos = float3( 0 , 0 , 0);

              o.worldPos = finalPos;

              o.pos = mul (UNITY_MATRIX_VP, float4(o.worldPos,1.0f));
              o.nor = finalNor;
              o.uv = finalUV;
              o.debug = float3( 1 , 0 , 0 );


              // o.debug = float3( 1 , 0 , 0);// * nor;//o.worldPos - og.pos;

               o.eye = _WorldSpaceCameraPos - o.worldPos;
              // o.uv = v.uv;
              // o.nor = v.nor;
                return o;

            }
 
            //Pixel function returns a solid color for each point.
            float4 frag (varyings v) : COLOR {
	

								float3 fNorm = uvNormalMap( _NormalMap , v.pos ,  v.uv  * float2( 1. , .2), v.nor , 1.1 , 1.1 );
  
              	float3 fRefl = reflect( -v.eye , fNorm );
                float3 cubeCol = texCUBE(_CubeMap, normalize( fRefl ) ).rgb;


                float3 col1 = lerp( v.col , cubeCol * (fNorm * .5 +.5) , clamp(v.uv.x *3 ,0,1) ); 
                float3 col2 = lerp( cubeCol * (fNorm * .5 +.5) , float3(1,1,1) , clamp((v.uv.x  -.8) * 10 ,0,1) ); 



            		float3 fCol = lerp( col1 , col2 , v.uv.x); //v.nor * .5 + .5;//float3( v.uv.x , v.uv.y , 0 );
                return float4( fCol , 1.);
            }
 
            ENDCG
 
        }
    }
 
    Fallback Off
	
}
