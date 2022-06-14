varying highp vec2 textureCoordinate;

uniform sampler2D inputImageTexture;

uniform highp float square[8];
uniform highp float points[36*2];
uniform int count;

const highp float pi = 3.1415926538;

void main()
{
    highp float a1x = square[0];
    highp float a1y = square[1];
    highp float a2x = square[2];
    highp float a2y = square[3];
    highp float a3x = square[4];
    highp float a3y = square[5];
    highp float a4x = square[6];
    highp float a4y = square[7];
    
    highp vec2 center = vec2((a1x + a2x)/2.0, (a1y + a3y)/2.0);
    highp vec2 textureCoordinateNew = textureCoordinate - center;
    highp float angle = atan(textureCoordinateNew.y, textureCoordinateNew.x);
    highp float angleOld = angle;
    
    if(angle >= -1.0 * pi && angle < -0.5*pi) {
        angle += 2.0*pi;
    }
    angle = (angle + 0.5 * pi)/(2.0 * pi);
    //count = count -1;

    highp float angleNew = angle * float(count);
    int n1 = int(clamp(floor(angleNew), 0.0, 36.0));
    int n2 = int(clamp(ceil(angleNew), 0.0, 36.0));
    if(n1 == 36) {
        n1 = 0;
    }
    if(n2 == 36) {
        n2 = 0;
    }
    highp vec2 near = mix(vec2(points[n1*2], points[n1*2 + 1]), vec2(points[n2*2], points[n2*2 + 1]), fract(angleNew));
    highp float far = 0.0;

    highp float halfHeight = (a3y - a1y) / 2.0;
    highp float halfWidth = (a2x - a1x) / 2.0;
    highp float stepVertical = atan(halfWidth / halfHeight) /(2.0*pi);
    highp float stepHonri = 0.25 - stepVertical;
    if(angle >=0.0 && angle < stepVertical || angle >= 1.0 - stepVertical && angle < 1.0) {
        far = -halfHeight / sin(angleOld);
    } else if(angle >= stepVertical && angle < stepVertical + 2.0 * stepHonri) {
        far = halfWidth / cos(angleOld);
    } else if(angle >= stepVertical + 2.0 * stepHonri && angle < 3.0 * stepVertical + 2.0 * stepHonri) {
        far = halfHeight / sin(angleOld);
    } else {
        far = -halfWidth / cos(angleOld);
    }
    
    highp float dis = distance(center, textureCoordinate);
    highp float disNear = distance(center, near);
    highp float scaleFromNear = min(halfWidth / 8.0, disNear);
    highp float startScale = disNear - scaleFromNear;
    highp float endScale = far - min(halfWidth/32.0, far - disNear);
    highp float scaleLen = scaleFromNear / 2.0;
    highp float scaleEnd = startScale + scaleLen;
    
    highp vec2 newCordToUse;
    if(dis <= startScale || dis > far || disNear >= far || startScale >= endScale) {
        newCordToUse = textureCoordinate;
    } else if(dis > startScale && dis <= endScale) {
        highp float ratio = (dis - startScale) / (endScale - startScale);
        highp float disNew = ratio * scaleLen + startScale;
        newCordToUse = center + vec2(disNew * cos(angleOld), disNew * sin(angleOld));
    } else {
        highp float ratio = (dis - endScale) / (far - endScale);
        highp float disNew = ratio * (far - scaleEnd) + scaleEnd;
        newCordToUse = center + vec2(disNew * cos(angleOld), disNew * sin(angleOld));
    }
    gl_FragColor = texture2D(inputImageTexture, newCordToUse);
//    if(dis <= disNear - 1.0/16.0) {
//        gl_FragColor = vec4(1,0,0,1);
//    } else if(dis <= far) {
//        gl_FragColor = vec4(0,1,0,1);
//    } else {
//        gl_FragColor = vec4(0,0,1,1);
//    }
//    if(textureCoordinate.x > a1x && textureCoordinate.x < a2x && textureCoordinate.y > a1y && textureCoordinate.y < a3y) {
//        if(distance(center, textureCoordinate) <= distance(center, near)) {
//            gl_FragColor = vec4(vec3(distance(center, near)), 1.0);
//        } else {
//            gl_FragColor = vec4(1,0,0,1);
//        }
//    } else {
//        gl_FragColor = vec4(0,1,0,1);
//    }
}
