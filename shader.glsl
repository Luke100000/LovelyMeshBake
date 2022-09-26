varying float edge;

#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float e = 1.0 - pow(edge, 1.0) * 0.5;
    return Texel(tex, tc) * color * vec4(e, e, e, 1.0);
}
#endif

#ifdef VERTEX
attribute float Edge;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    edge = Edge;
    return transform_projection * vertex_position;
}
#endif