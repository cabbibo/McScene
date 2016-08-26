using UnityEngine;
using System.Collections;

public class Grassify : MonoBehaviour {


  public ComputeShader physics;
  public Material material;
  public Material lineMaterial;
  public GameObject handBufferInfo;
  public int bladeLength = 8;
  public int bladeWidth = 6;
  public int bladeResolution = 25;

  private const int threadX = 4;
  private const int threadY = 4;
  private const int threadZ = 4;

  private const int strideX = 4;
  private const int strideY = 4;
  private const int strideZ = 4;

  private int gridX { get { return threadX * strideX; } }
  private int gridY { get { return threadY * strideY; } }
  private int gridZ { get { return threadZ * strideZ; } }

  private int vertexCount { get { return gridX * gridY * gridZ; } }

  private int numBlades { get { return vertexCount / bladeLength; } }

  private int _kernel;

  private ComputeBuffer _vertBuffer;
  private ComputeBuffer _transBuffer;

  private float[] transValues = new float[32];

  private Mesh mesh;

  public struct Vert{
    public Vector3 pos; 
    public Vector3 vel;
    public Vector3 nor;
    public Vector2 uv;
    public Vector2 texUV;
    public float  bladeID;
    public float downID;
    public float upID;
    public Vector3 debug;
  };

  
  private int[]     triangles;
  private Vector4[] tangents;
  private Vector3[] normals;
  private Vector2[] uvs;
  private Vector3[] positions;
  private Color[]   colors;

  int VertStructSize = 3 + 3+ 3+ 2+2+1+1+1+3;


	// Use this for initialization
	void Start () {

    mesh = GetComponent<MeshFilter>().mesh;
    triangles = mesh.triangles;
    tangents = mesh.tangents;
    normals = mesh.normals;
    uvs = mesh.uv;
    Debug.Log( uvs.Length );
    positions = mesh.vertices;
    colors = mesh.colors;

    createBuffers();
    _kernel = physics.FindKernel("CSMain");

    Camera.onPostRender += Render;

    // Hit it w/ a dispatch first time
    Dispatch();

	}

  //When this GameObject is disabled we must release the buffers or else Unity complains.
  private void OnDisable(){
    Camera.onPostRender -= Render;
    ReleaseBuffer();
  }
    //Remember to release buffers and destroy the material when play has been stopped.
  void ReleaseBuffer(){

    _vertBuffer.Release(); 
    _transBuffer.Release(); 

  }



  private void FixedUpdate(){
    Dispatch();
  }

   //After all rendering is complete we dispatch the compute shader and then set the material before drawing with DrawProcedural
  //this just draws the "mesh" as a set of points
  private void Render(Camera camera) {


    int numVertsTotal = bladeWidth * (bladeResolution) * 6 * numBlades;
    



   lineMaterial.SetPass(0);
   lineMaterial.SetBuffer("vertBuffer", _vertBuffer);
   lineMaterial.SetInt("_BladeLength"   ,bladeLength);
   Graphics.DrawProcedural(MeshTopology.Lines, (bladeLength-1) * numBlades);

       material.SetPass(0);

    material.SetBuffer("vertBuffer", _vertBuffer);

    material.SetInt("_TotalVerts" ,vertexCount);
    material.SetInt("_BladeWidth" ,bladeWidth);
    material.SetInt("_BladeLength" ,bladeLength);
    material.SetInt("_BladeResolution" ,bladeResolution);

    material.SetMatrix("worldMat", transform.localToWorldMatrix);
    material.SetMatrix("invWorldMat", transform.worldToLocalMatrix);

    Graphics.DrawProcedural(MeshTopology.Triangles, numVertsTotal);
//



  }


  private Vector3 getLocationFromBladeIDAndRow( int bladeID ,float row ){

    return positions[bladeID] + normals[bladeID] * (row / bladeLength) * 2.1f;

  }

  private void createBuffers() {

    _vertBuffer = new ComputeBuffer( vertexCount ,  VertStructSize * sizeof(float));
    _transBuffer = new ComputeBuffer( 32 ,  sizeof(float));
    

    float[] inValues = new float[ VertStructSize * vertexCount];
    float[] ogValues = new float[ 3         * vertexCount];

    int index = 0;


    for (int z = 0; z < gridZ; z++) {
      for (int y = 0; y < gridY; y++) {
        for (int x = 0; x < gridX; x++) {

          int id = x + y * gridX + z * gridX * gridY; 

          float bladeID = Mathf.Floor( id / bladeLength );
          
          float row = (float)(id % bladeLength );



          float uvX = bladeID / (float)numBlades;
          float uvY = row / bladeLength;

          int fID = (int)bladeID * 3;
          Vector3 pos = positions[fID];
          Vector3 nor = normals[fID];

          Vector3 fVec = pos + nor * (row / bladeLength) * 2.1f;

          float downID = id - 1;
          float upID = id + 1;

          if( row == 0 ){ downID = -1; }
          if( row == bladeLength -1 ){ upID = -1; }
          Vert vert = new Vert();

          vert.pos = transform.TransformPoint(fVec);
          vert.vel = new Vector3( 0 , 0 , 0 );
          vert.nor = transform.TransformDirection( nor );
          vert.uv  = new Vector2( uvX , uvY );
          vert.texUV  = uvs[fID];
          vert.bladeID = bladeID;
          vert.downID = downID;
          vert.upID = upID;

          Vector3 debug = new Vector3( 0 , 0 ,0);
          if( row == 7 ){ debug= new Vector3( 1, 1, 1);}
          if( row == 0 ){ debug = new Vector3( 1, 0 , 0);}
          vert.debug = debug;

          AssignVertStruct( inValues , index , out index , vert );

        }
      }
    }

    _vertBuffer.SetData(inValues);

  }


  public static void AssignVertStruct( float[] inValues , int id , out int index , Vert i ){

    index = id;

    //pos
    // need to be slightly different to not get infinte forces
    inValues[index++] = i.pos.x;
    inValues[index++] = i.pos.y;
    inValues[index++] = i.pos.z;
   
    //vel
    inValues[index++] = i.vel.x; //Random.Range(-.00f , .00f );
    inValues[index++] = i.vel.y; //Random.Range(-.00f , .00f );
    inValues[index++] = i.vel.z; //Random.Range(-.00f , .00f );

    //nor
    inValues[index++] = i.nor.x;
    inValues[index++] = i.nor.y;
    inValues[index++] = i.nor.z;

    //uv
    inValues[index++] = i.uv.x;
    inValues[index++] = i.uv.y;

    //uv
    inValues[index++] = i.texUV.x;
    inValues[index++] = i.texUV.y;

    //ribbon id
    inValues[index++] = i.bladeID;
    inValues[index++] = i.downID;
    inValues[index++] = i.upID;


    //debug
    inValues[index++] = i.debug.x;
    inValues[index++] = i.debug.y;
    inValues[index++] = i.debug.z;

  }


     private void Dispatch() {



      //audioTexture = pedestal.GetComponent<audioSourceTexture>().AudioTexture;

      AssignStructs.AssignTransBuffer( transform , transValues , _transBuffer );
      //AssignStructs.AssignDisformerBuffer( Disformers , disformValues , _disformBuffer );

      
      physics.SetInt( "_NumberHands", handBufferInfo.GetComponent<HandBuffer>().numberHands );

      physics.SetFloat( "_DeltaTime"    , Time.deltaTime );
      physics.SetFloat( "_Time"         , Time.time      );



      //physics.SetTexture(_kernel,"_Audio", audioTexture);

      physics.SetBuffer( _kernel , "transBuffer"  , _transBuffer    );
      physics.SetBuffer( _kernel , "vertBuffer"   , _vertBuffer     );
      //physics.SetBuffer( _kernel , "disformBuffer", _disformBuffer  );
      physics.SetBuffer( _kernel , "handBuffer"   , handBufferInfo.GetComponent<HandBuffer>()._handBuffer );

      physics.Dispatch(_kernel, strideX , strideY , strideZ );



    }



}
