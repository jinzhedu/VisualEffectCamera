//
//  PanFaceFilter.swift
//  VisualEffectCamera
//
//  Created by du jinzhe on 2022/6/15.
//

#if canImport(OpenGL)
import OpenGL.GL3
#endif

#if canImport(OpenGLES)
import OpenGLES
#endif

#if canImport(COpenGLES)
import COpenGLES.gles2
let GL_DEPTH24_STENCIL8 = GL_DEPTH24_STENCIL8_OES
let GL_TRUE = GLboolean(1)
let GL_FALSE = GLboolean(0)
#endif

#if canImport(COpenGL)
import COpenGL
#endif

import Foundation
import GPUImage


public class PanFaceFilter: BasicOperation {
    var imageVertices:[Float]?
    var texCords:[Float]?
    
    public init() {
        super.init(fragmentShader:PassthroughFragmentShader)
    }
    
    open override func renderFrame() {
        renderFramebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation:.portrait, size:sizeOfInitialStageBasedOnFramebuffer(inputFramebuffers[0]!), stencil:mask != nil)
        
        let textureProperties = initialTextureProperties()
        configureFramebufferSpecificUniforms(inputFramebuffers[0]!)
        
        renderFramebuffer.activateFramebufferForRendering()
        clearFramebufferWithColor(Color.transparent)
        internalRenderFunction(inputFramebuffers[0]!, textureProperties:textureProperties)
    }
    
    open override func internalRenderFunction(_ inputFramebuffer:Framebuffer, textureProperties:[InputTextureProperties]) {
        guard let vertices = imageVertices else { return }
        renderQuadWithShader(shader, uniformSettings:uniformSettings, vertexBufferObject:generateVBO(for:vertices), inputTextures:textureProperties, calVertexNum: true)
        releaseIncomingFramebuffers()
    }
    
    open override func initialTextureProperties() -> [InputTextureProperties] {
        var inputTextureProperties = [InputTextureProperties]()
        
        if let outputRotation = overriddenOutputRotation {
            for framebufferIndex in 0..<inputFramebuffers.count {
                inputTextureProperties.append(InputTextureProperties(textureVBO:generateVBO(for: [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]), texture:inputFramebuffers[UInt(framebufferIndex)]!.texture))
            }
        } else {
            for framebufferIndex in 0..<inputFramebuffers.count {
                inputTextureProperties.append(InputTextureProperties(textureVBO:generateVBO(for: texCords ?? [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]), texture:inputFramebuffers[UInt(framebufferIndex)]!.texture))
            }
        }
        
        return inputTextureProperties
    }
}

