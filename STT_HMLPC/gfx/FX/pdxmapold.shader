## Includes

Includes = {
	"constants.fxh"
	"standardfuncsgfx.fxh"
	"pdxmap.fxh"
	"shadow.fxh"
}


## Samplers

PixelShader = 
{
	Samplers = 
	{
		TerrainDiffuse = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 0
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		HeightNormal = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 1
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		TerrainColorTint = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 2
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		TerrainColorTintSecond = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 3
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		TerrainNormal = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 4
			MipFilter = "Point"
			MinFilter = "Linear"
		}

		TerrainIDMap = 
		{
			AddressV = "Clamp"
			MagFilter = "Point"
			AddressU = "Clamp"
			Index = 5
			MipFilter = "None"
			MinFilter = "Point"
		}

		ProvinceSecondaryColorMap = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 6
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		FoWTexture = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 7
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		FoWDiffuse = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 8
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		OccupationMask = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 9
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		ProvinceColorMap = 
		{
			AddressV = "Clamp"
			MagFilter = "Linear"
			AddressU = "Clamp"
			Index = 10
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		ProvinceSecondaryColorMapPoint = 
		{
			AddressV = "Wrap"
			MagFilter = "Point"
			AddressU = "Wrap"
			Index = 11
			MipFilter = "Point"
			MinFilter = "Point"
		}

		ShadowMap = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 12
			MipFilter = "Linear"
			MinFilter = "Linear"
		}

		TITexture = 
		{
			AddressV = "Wrap"
			MagFilter = "Linear"
			AddressU = "Wrap"
			Index = 13
			MipFilter = "Linear"
			MinFilter = "Linear"
		}


	}
}


## Vertex Structs

VertexStruct VS_INPUT_TERRAIN_NOTEXTURE
{
    float4 position			: POSITION;
	float2 height			: TEXCOORD0;
};


VertexStruct VS_OUTPUT_TERRAIN
{
    float4 position			: PDX_POSITION;
	float2 uv				: TEXCOORD0;
	float2 uv2				: TEXCOORD1;
	float3 prepos 			: TEXCOORD2;
	float4 vShadowProj		: TEXCOORD3;
	float4 vScreenCoord		: TEXCOORD4;
};


## Constant Buffers



## Shared Code

Code
[[
//static const float3 GREYIFY = float3( 0.212671, 0.715160, 0.072169 );
static const float3 GREYIFY = float3( 0.2, 0.7, 0.07 );
static const float NUM_TILES = 4.0f;
static const float TEXELS_PER_TILE = 512.0f;
static const float ATLAS_TEXEL_POW2_EXPONENT= 11.0f;
static const float TERRAIN_WATER_CLIP_HEIGHT = 3.0f;
static const float TERRAIN_UNDERWATER_CLIP_HEIGHT = 3.0f;


float mipmapLevel( float2 uv )
{

#ifdef PDX_OPENGL

#ifdef NO_SHADER_TEXTURE_LOD
	return 1.0f;
#else

#ifdef	PIXEL_SHADER
	float dx = fwidth( uv.x * TEXELS_PER_TILE );
	float dy = fwidth( uv.y * TEXELS_PER_TILE );
    float d = max( dot(dx, dx), dot(dy, dy) );
	return 0.5 * log2( d );
#else
	return 3.0f;
#endif //PIXEL_SHADER

#endif // NO_SHADER_TEXTURE_LOD

#else
    float2 dx = ddx( uv * TEXELS_PER_TILE );
    float2 dy = ddy( uv * TEXELS_PER_TILE );
    float d = max( dot(dx, dx), dot(dy, dy) );
    return 0.5f * log2( d );
#endif //PDX_OPENGL
}

float4 sample_terrain( float IndexU, float IndexV, float2 vTileRepeat, float vMipTexels, float lod )
{
	vTileRepeat = frac( vTileRepeat );
#ifdef NO_SHADER_TEXTURE_LOD
	vTileRepeat *= 0.96;
	vTileRepeat += 0.02;
#endif
	
	float vTexelsPerTile = vMipTexels / NUM_TILES;

	vTileRepeat *= ( vTexelsPerTile - 1.0f ) / vTexelsPerTile;
	return float4( ( float2( IndexU, IndexV ) + vTileRepeat ) / NUM_TILES + 0.5f / vMipTexels, 0.0f, lod );
}

void calculate_index( float4 IDs, out float4 IndexU, out float4 IndexV, out float vAllSame )
{
	IDs *= 255.0f;
	vAllSame = saturate( IDs.z - 98.0f ); // we've added 100 to first if all IDs are same
	IDs.z -= vAllSame * 100.0f;

	IndexV = trunc( ( IDs + 0.5f ) / NUM_TILES );
	IndexU = trunc( IDs - ( IndexV * NUM_TILES ) + 0.5f );
}

#ifdef	PIXEL_SHADER

float3 calculate_secondary( float2 uv, float3 vColor, float2 vPos )
{
	float4 vSample = tex2D( ProvinceSecondaryColorMap, uv );
	float4 vMask = tex2D( OccupationMask, vPos / 8.0f ).rgba;
	return lerp( vColor, vSample.rgb, saturate( vSample.a * vMask.a ) );
}

float3 calculate_secondary_compressed( float2 uv, float3 vColor, float2 vPos )
{
	float4 vMask = tex2D( OccupationMask, vPos / 8.0 ).rgba;

	float4 vSecondary = float4( 
		tex2D( ProvinceSecondaryColorMapPoint, uv ).rgb, 
		tex2D( ProvinceSecondaryColorMap, uv ).a );

	const int nDivisor = 6;
	int3 vTest = int3(vSecondary.rgb * 255.0);
	
	int3 RedParts = int3( vTest / ( nDivisor * nDivisor ) );
	vTest -= RedParts * ( nDivisor * nDivisor );

	int3 GreenParts = int3( vTest / nDivisor );
	vTest -= GreenParts * nDivisor;

	int3 BlueParts = int3( vTest );

	
	float3 vSecondColor = 
		  float3( RedParts.x, GreenParts.x, BlueParts.x ) * vMask.b
		+ float3( RedParts.y, GreenParts.y, BlueParts.y ) * vMask.g
		+ float3( RedParts.z, GreenParts.z, BlueParts.z ) * vMask.r;

	vSecondary.a -= 0.5 * saturate( saturate( frac( vPos.x / 2.0 ) - 0.7 ) * 10000.0 );
	vSecondary.a = saturate( saturate( vSecondary.a ) * 3.0 ) * vMask.a;

	return vColor * ( 1.0 - vSecondary.a ) + ( vSecondColor / float(nDivisor) ) * vSecondary.a;
}

#endif // PIXEL_SHADER
]]


## Vertex Shaders

VertexShader = 
{
	MainCode VertexShader
	[[
		VS_OUTPUT_TERRAIN main( const VS_INPUT_TERRAIN_NOTEXTURE VertexIn )
		{
			VS_OUTPUT_TERRAIN VertexOut;
			
			float2 pos = VertexIn.position.xy * QuadOffset_Scale_IsDetail.z + QuadOffset_Scale_IsDetail.xy;
			float vSatPosZ = saturate( VertexIn.position.z ); // VertexIn.position.z can have a value [0-4], if != 0 then we shall displace vertex
			float vUseAltHeight = vSatPosZ * vSnap[ int( VertexIn.position.z - 1.0f ) ]; // the snap values are set to either 0 or 1 before each draw call to enable/disable snapping due to LOD
			pos += vUseAltHeight 
				* float2( 1.0f - VertexIn.position.w, VertexIn.position.w ) // VertexIn.position.w determines offset direction
				* QuadOffset_Scale_IsDetail.z; // and of course we need to scale it to the same LOD
			VertexOut.uv = float2( ( pos.x + 0.5f ) / MAP_SIZE_X,  ( pos.y + 0.5f ) / MAP_SIZE_Y );
			VertexOut.uv2.x = ( pos.x + 0.5f ) / MAP_SIZE_X;
			VertexOut.uv2.y = ( pos.y + 0.5f - MAP_SIZE_Y ) / -MAP_SIZE_Y;	
			VertexOut.uv2.xy *= float2( MAP_POW2_X, MAP_POW2_Y ); //POW2
			float vHeight = VertexIn.height.x * ( 1.0f - vUseAltHeight ) + VertexIn.height.y * vUseAltHeight;
			vHeight *= 0.01f;
			VertexOut.prepos = float3( pos.x, vHeight, pos.y );
			VertexOut.position = mul( ViewProjectionMatrix, float4( VertexOut.prepos, 1.0f ) );
			
			VertexOut.vShadowProj = mul( ShadowMapTextureMatrix, float4( VertexOut.prepos, 1.0f ) );
			
			// Output the screen-space texture coordinates
			VertexOut.vScreenCoord.x = ( VertexOut.position.x * 0.5 + VertexOut.position.w * 0.5 );
			VertexOut.vScreenCoord.y = ( VertexOut.position.w * 0.5 - VertexOut.position.y * 0.5 );
		#ifdef PDX_OPENGL
			VertexOut.vScreenCoord.y = -VertexOut.vScreenCoord.y;
		#endif	
			VertexOut.vScreenCoord.z = VertexOut.position.w;
			VertexOut.vScreenCoord.w = VertexOut.position.w;	
			
			return VertexOut;
		}
	]]

}


## Pixel Shaders

PixelShader = 
{
	MainCode PixelShaderUnderwater
	[[
		float4 main( VS_OUTPUT_TERRAIN Input ) : PDX_COLOR
		{
			clip( WATER_HEIGHT - Input.prepos.y + TERRAIN_WATER_CLIP_HEIGHT );
			float3 normal = normalize( tex2D( HeightNormal,Input.uv2 ).rbg - 0.5f );
			float3 diffuseColor = tex2D( TerrainDiffuse, Input.uv2 * float2(( MAP_SIZE_X / 32.0f ), ( MAP_SIZE_Y / 32.0f ) ) ).rgb;
			float3 waterColorTint = tex2D( TerrainColorTint, Input.uv2 ).rgb;
			
			float vMin = 17.0f;
			float vMax = 18.5f;
			float vWaterFog = saturate( 1.0f - ( Input.prepos.y - vMin ) / ( vMax - vMin ) );
			
			diffuseColor = lerp( diffuseColor, waterColorTint, vWaterFog );
			float vFog = saturate( Input.prepos.y * Input.prepos.y * Input.prepos.y * WATER_HEIGHT_RECP_SQUARED * WATER_HEIGHT_RECP  );
			float3 vOut = CalculateMapLighting( diffuseColor, normal * vFog );
			
			return float4( vOut, 1.0f );
		}
	]]

	MainCode PixelShaderColor
	[[
		float4 main( VS_OUTPUT_TERRAIN Input ) : PDX_COLOR
		{
		#ifndef MAP_IGNORE_CLIP_HEIGHT
			clip( Input.prepos.y + TERRAIN_WATER_CLIP_HEIGHT - WATER_HEIGHT );
		#endif	
			float4 vFoWColor = GetFoWColor( Input.prepos, FoWTexture);	
			float TI = GetTI( vFoWColor );	
			float4 vTIColor = GetTIColor( Input.prepos, TITexture );

			if( ( TI - 0.99f ) * 1000.0f > 0.0f )
			{
				return float4( vTIColor.rgb, 1.0f );
			}	
			
			float2 vOffsets = float2( -0.5f / MAP_SIZE_X, -0.5f / MAP_SIZE_Y );
			
			float vAllSame;
			float4 IndexU;
			float4 IndexV;
			calculate_index( tex2D( TerrainIDMap, Input.uv + vOffsets.xy ), IndexU, IndexV, vAllSame );
			float2 vTileRepeat = Input.uv2 * TERRAIN_TILE_FREQ;
			vTileRepeat.x *= MAP_SIZE_X/MAP_SIZE_Y;
			
			float lod = clamp( trunc( mipmapLevel( vTileRepeat ) - 0.5f ), 0.0f, 6.0f );
			float vMipTexels = pow( 2.0f, ATLAS_TEXEL_POW2_EXPONENT - lod );
			float3 normal = normalize( tex2D( HeightNormal, Input.uv2 ).rbg - 0.5f );
			
			float4 sampleTerrain = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.w, IndexV.w, vTileRepeat, vMipTexels, lod ) );
			float3 terrain_color = tex2D( ProvinceColorMap, Input.uv ).rgb;
			
			if ( vAllSame < 1.0f && vBorderLookup_HeightScale_UseMultisample_SeasonLerp.z < 8.0f )
			{
				float4 ColorRD = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.x, IndexV.x, vTileRepeat, vMipTexels, lod ) );
				float4 ColorLU = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.y, IndexV.y, vTileRepeat, vMipTexels, lod ) );
				float4 ColorRU = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.z, IndexV.z, vTileRepeat, vMipTexels, lod ) );
				float3 terrain_colorRD = tex2D( ProvinceColorMap, Input.uv + vOffsets.yx ).rgb;
				float3 terrain_colorLU = tex2D( ProvinceColorMap, Input.uv + vOffsets.xy ).rgb;
				float3 terrain_colorRU = tex2D( ProvinceColorMap, Input.uv + vOffsets.yy ).rgb;
				float2 vFrac = frac( float2( Input.uv.x * MAP_SIZE_X - 0.5f, Input.uv.y * MAP_SIZE_Y - 0.5f ) );
				
				float vAlphaFactor = 10.0f;
				float4 vTest = float4( 
					vFrac.x + vFrac.x * ColorLU.a * vAlphaFactor, 
					(1.0f - vFrac.x) + (1.0f - vFrac.x) * ColorRU.a * vAlphaFactor, 
					vFrac.x + vFrac.x * sampleTerrain.a * vAlphaFactor, 
					(1.0f - vFrac.x) + (1.0f - vFrac.x) * ColorRD.a * vAlphaFactor );
				float2 yWeights = float2( ( vTest.x + vTest.y ) * vFrac.y, ( vTest.z + vTest.w ) * ( 1.0f - vFrac.y ) );
				float3 vBlendFactors = float3( vTest.x / ( vTest.x + vTest.y ),
					vTest.z / ( vTest.z + vTest.w ),
					yWeights.x / ( yWeights.x + yWeights.y ) );
				sampleTerrain = lerp( 
					lerp( ColorRU, ColorLU, vBlendFactors.x ),
					lerp( ColorRD, sampleTerrain, vBlendFactors.y ), 
					vBlendFactors.z );
			}
			
			float3 TerrainColor = lerp( tex2D( TerrainColorTint, Input.uv2 ), tex2D( TerrainColorTintSecond, Input.uv2 ), vBorderLookup_HeightScale_UseMultisample_SeasonLerp.w ).rgb;	
			sampleTerrain.rgb = GetOverlay( sampleTerrain.rgb, TerrainColor, 0.5f );
			
			float2 vBlend = float2( 0.1f, 0.65f );
			float3 vOut = ( dot(sampleTerrain.rgb, GREYIFY) * vBlend.x + terrain_color.rgb * vBlend.y );
//			vOut = CalculateMapLighting( vOut, normal );
			vOut = calculate_secondary( Input.uv, vOut, Input.prepos.xz );
			
		#ifndef PDX_OPENGLES			
			// Grab the shadow term
			float fShadowTerm = GetShadowScaled( SHADOW_WEIGHT_MAP, Input.vScreenCoord, ShadowMap );
			vOut *= fShadowTerm;
		#endif 

			vOut = ApplyDistanceFog( vOut, Input.prepos, GetFoWColor( Input.prepos, FoWTexture), FoWDiffuse );
			return float4( lerp( ComposeSpecular( vOut, 0.0f ), vTIColor.rgb, TI ), 1.0f );
		}
	]]

	MainCode PixelShaderTerrain
	[[
		float4 main( VS_OUTPUT_TERRAIN Input ) : PDX_COLOR
		{
			//return float4( tex2D( ProvinceColorMap, Input.uv2 ).rgb, 1.0f );
		#ifndef MAP_IGNORE_CLIP_HEIGHT
			clip( Input.prepos.y + TERRAIN_WATER_CLIP_HEIGHT - WATER_HEIGHT );
		#endif	
			
			float4 vFoWColor = GetFoWColor( Input.prepos, FoWTexture);			
			float TI = GetTI( vFoWColor );	
			float4 vTIColor = GetTIColor( Input.prepos, TITexture );
			if( ( TI - 0.99f ) * 1000.0f > 0.0f )
			{
				return float4( vTIColor.rgb, 1.0f );
			}
			
			float2 vOffsets = float2( -0.5f / MAP_SIZE_X, -0.5f / MAP_SIZE_Y );
			
			float vAllSame;
			float4 IndexU;
			float4 IndexV;
			calculate_index( tex2D( TerrainIDMap, Input.uv + vOffsets.xy ), IndexU, IndexV, vAllSame );
			
			float2 vTileRepeat = Input.uv2 * TERRAIN_TILE_FREQ;
			vTileRepeat.x *= MAP_SIZE_X/MAP_SIZE_Y;
			
			float lod = clamp( trunc( mipmapLevel( vTileRepeat ) - 0.5f ), 0.0f, 6.0f );
			float vMipTexels = pow( 2.0f, ATLAS_TEXEL_POW2_EXPONENT - lod );
			float3 normal = normalize( tex2D( HeightNormal, Input.uv2 ).rbg - 0.5f );
			float4 sampleTerrain = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.w, IndexV.w, vTileRepeat, vMipTexels, lod ) );
		#ifdef NO_SHADER_TEXTURE_LOD
			float3 terrain_normal = float3( 0,1,0 );
		#else	
			float3 terrain_normal = tex2Dlod( TerrainNormal, sample_terrain( IndexU.w, IndexV.w, vTileRepeat, vMipTexels, lod ) ).rbg - 0.5f;
		#endif //NO_SHADER_TEXTURE_LOD
			
			if ( vAllSame < 1.0f && vBorderLookup_HeightScale_UseMultisample_SeasonLerp.z < 8.0f )
			{
				float4 ColorRD = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.x, IndexV.x, vTileRepeat, vMipTexels, lod ) );
				float4 ColorLU = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.y, IndexV.y, vTileRepeat, vMipTexels, lod ) );
				float4 ColorRU = tex2Dlod( TerrainDiffuse, sample_terrain( IndexU.z, IndexV.z, vTileRepeat, vMipTexels, lod ) );
		#ifndef NO_SHADER_TEXTURE_LOD		
				float3 terrain_normalRD = tex2Dlod( TerrainNormal, sample_terrain( IndexU.x, IndexV.x, vTileRepeat, vMipTexels, lod ) ).rbg - 0.5f;
				float3 terrain_normalLU = tex2Dlod( TerrainNormal, sample_terrain( IndexU.y, IndexV.y, vTileRepeat, vMipTexels, lod ) ).rbg - 0.5f;
				float3 terrain_normalRU = tex2Dlod( TerrainNormal, sample_terrain( IndexU.z, IndexV.z, vTileRepeat, vMipTexels, lod ) ).rbg - 0.5f;
		#endif //NO_SHADER_TEXTURE_LOD
				float2 vFrac = frac( float2( Input.uv.x * MAP_SIZE_X - 0.5f, Input.uv.y * MAP_SIZE_Y - 0.5f ) );
				float vAlphaFactor = 10.0f;
				float4 vTest = float4( 
					vFrac.x + vFrac.x * ColorLU.a * vAlphaFactor, 
					(1.0f - vFrac.x) + (1.0f - vFrac.x) * ColorRU.a * vAlphaFactor, 
					vFrac.x + vFrac.x * sampleTerrain.a * vAlphaFactor, 
					(1.0f - vFrac.x) + (1.0f - vFrac.x) * ColorRD.a * vAlphaFactor );
				float2 yWeights = float2( ( vTest.x + vTest.y ) * vFrac.y, ( vTest.z + vTest.w ) * ( 1.0f - vFrac.y ) );
				float3 vBlendFactors = float3( vTest.x / ( vTest.x + vTest.y ),
					vTest.z / ( vTest.z + vTest.w ),
					yWeights.x / ( yWeights.x + yWeights.y ) );
				sampleTerrain = lerp( 
					lerp( ColorRU, ColorLU, vBlendFactors.x ),
					lerp( ColorRD, sampleTerrain, vBlendFactors.y ), 
					vBlendFactors.z );
		#ifndef NO_SHADER_TEXTURE_LOD			
				terrain_normal = 
					( terrain_normalRU * ( 1.0f - vBlendFactors.x ) + terrain_normalLU * vBlendFactors.x ) * ( 1.0f - vBlendFactors.z ) +
					( terrain_normalRD * ( 1.0f - vBlendFactors.y ) + terrain_normal   * vBlendFactors.y ) * vBlendFactors.z;
		#endif //NO_SHADER_TEXTURE_LOD			
			}
			terrain_normal = normalize( terrain_normal );
			
			//Calculate normal
			float3 zaxis = normal; //normal
			float3 xaxis = cross( zaxis, float3( 0, 0, 1 ) ); //tangent
			xaxis = normalize( xaxis );
			float3 yaxis = cross( xaxis, zaxis ); //bitangent
			yaxis = normalize( yaxis );
			normal = xaxis * terrain_normal.x + zaxis * terrain_normal.y + yaxis * terrain_normal.z;
			//return float4( dot(-vLightDir, normal).xxx, 1.0f );
			
			float3 TerrainColor = lerp( tex2D( TerrainColorTint, Input.uv2 ), tex2D( TerrainColorTintSecond, Input.uv2 ), vBorderLookup_HeightScale_UseMultisample_SeasonLerp.w ).rgb;
			
			sampleTerrain.rgb = GetOverlay( sampleTerrain.rgb, TerrainColor, 0.75f );
			sampleTerrain.rgb = ApplySnow( sampleTerrain.rgb, Input.prepos, normal, vFoWColor, FoWDiffuse );
			sampleTerrain.rgb = calculate_secondary_compressed( Input.uv, sampleTerrain.rgb, Input.prepos.xz );	
			
			float3 vOut = CalculateMapLighting( sampleTerrain.rgb, normal );
			
		#ifndef PDX_OPENGLES
			// Grab the shadow term
			float fShadowTerm = GetShadowScaled( SHADOW_WEIGHT_TERRAIN, Input.vScreenCoord, ShadowMap );
			vOut *= fShadowTerm;
		#endif 

			vOut = ApplyDistanceFog( vOut, Input.prepos, vFoWColor, FoWDiffuse );
			return float4( lerp( ComposeSpecular( vOut, 0.0f ), vTIColor.rgb, TI ), 1.0f );
		}
	]]

	MainCode PixelShaderTerrainUnlit
	[[
		float4 main( VS_OUTPUT_TERRAIN Input ) : PDX_COLOR
		{	
			// Grab the shadow term
			float fShadowTerm = CalculateShadow( Input.vShadowProj, ShadowMap);		
			return float4( fShadowTerm, fShadowTerm, fShadowTerm, 1.0f );
		}
	]]

}


## Blend States

BlendState BlendState
{
	AlphaTest = no
	BlendEnable = no
	WriteMask = "RED|GREEN|BLUE|ALPHA"
}

## Rasterizer States

## Depth Stencil States

## Effects

Effect terrainunlit
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderTerrainUnlit"
}

Effect terrain
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderTerrain"
}

Effect terrain_color
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderColor"
}

Effect underwater
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShaderUnderwater"
}