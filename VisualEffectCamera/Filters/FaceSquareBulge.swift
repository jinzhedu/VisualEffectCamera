import GPUImage
#if canImport(OpenGL)
import OpenGL.GL3
#endif

#if canImport(OpenGLES)
import OpenGLES
#endif

#if canImport(COpenGLES)
import COpenGLES.gles2
#endif

#if canImport(COpenGL)
import COpenGL
#endif
public class FaceSquareBulge: BasicOperation {
//    public var radius:Float = 0.25 { didSet { uniformSettings["radius"] = radius } }
//    public var scale:Float = 0.5 { didSet { uniformSettings["scale"] = scale } }
//    public var center:Position = Position.center { didSet { uniformSettings["center"] = center } }
    public var square:[GLfloat]? { didSet { uniformSettings["square"] = square } }
    public var count:Int = 0 { didSet { uniformSettings["count"] = count } }
    public var points:[GLfloat]? { didSet { uniformSettings["points"] = points } }
    
    public init() {
        super.init(fragmentShader:FaceSquareBulgeFragmentShader, numberOfInputs:1)
    }
}

//    if(angle > 0.5 * pi && angle <= pi) {
//        angle -= 2.0*pi;
//    }
//    angle = (0.5 * pi - angle)/(2.0 * pi);
//
//    highp float far = 0.0;
//    highp float near = 0.0;
//
//
//    if(textureCoordinate.x > a1x && textureCoordinate.x < a2x && textureCoordinate.y > a1y && textureCoordinate.y < a3y) {
//        highp float color = angle - mod(angle, 1.0/float(count));
//        gl_FragColor = vec4(vec3(color), 1.0);
//    } else {
//        gl_FragColor = vec4(0,1,0,1);
//    }
