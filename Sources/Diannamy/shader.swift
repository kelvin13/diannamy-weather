import Taylor
import SGLOpenGL

struct Shader
{
    private
    typealias Status_func = (GLuint, GLenum, UnsafeMutablePointer<GLint>) -> ()
    private
    typealias Log_func = (GLuint, GLint, UnsafeMutablePointer<GLsizei>, UnsafeMutablePointer<GLchar>) -> ()

    let program:GLuint

    let tex_u_ids:[GLint],
        u_ids:[GLint]

    init?(vertex_file:String, geometry_file:String? = nil, fragment_file:String? = nil,
          tex_uniforms:[String] = [], uniforms:[String] = [])
    {
        guard let vert_source:String = open_text_file(vertex_file)
        else
        {
            return nil
        }

        let geom_source:String?
        if let geometry_file:String = geometry_file
        {
            guard let _geom_source:String = open_text_file(geometry_file)
            else
            {
                return nil
            }

            geom_source = _geom_source
        }
        else
        {
            geom_source = nil
        }

        let frag_source:String?
        if let fragment_file:String = fragment_file
        {
            guard let _frag_source:String = open_text_file(fragment_file)
            else
            {
                return nil
            }

            frag_source = _frag_source
        }
        else
        {
            frag_source = nil
        }

        self.init(vertex_source: vert_source,
                  geometry_source: geom_source,
                  fragment_source: frag_source,
                  tex_uniforms: tex_uniforms,
                  uniforms: uniforms)
    }

    init?(vertex_source:String, geometry_source:String? = nil, fragment_source:String? = nil,
          tex_uniforms:[String] = [], uniforms:[String] = [])
    {
        let program:GLuint = glCreateProgram()
        var shaders:[GLuint] = []

        for (shader_source, shader_type):(String?, GLenum) in [(vertex_source  , GL_VERTEX_SHADER  ),
                                                               (fragment_source, GL_FRAGMENT_SHADER),
                                                               (geometry_source, GL_GEOMETRY_SHADER)]
        {
            guard let source:String = shader_source
            else
            {
                continue
            }
            guard let shader:GLuint = Shader.compile(source: source, type: shader_type)
            else
            {
                return nil
            }

            shaders.append(shader)
        }

        guard Shader.link(program: program, shaders: shaders)
        else
        {
            return nil
        }

        // standard uniform blocks
        let u_camera:GLuint = glGetUniformBlockIndex(program, "camera")
        // bind camera buffer to position 0
        glUniformBlockBinding(program, u_camera, 0)

        self.tex_u_ids = tex_uniforms.map{ glGetUniformLocation(program, $0) }
        self.u_ids     = uniforms.map{ glGetUniformLocation(program, $0) }
        self.program   = program
    }

    private static
    func compile(source:String, type shader_type:GLenum) -> GLuint?
    {
        let shader:GLuint = glCreateShader(type: shader_type)

        // this is inefficient cause we got the String from a CString originally
        source.withCString
        {
            glShaderSource(shader: shader,
                           count : 1,
                           string: [$0],
                           length: [-1])
        }
        glCompileShader(shader: shader)

        if let error_msg:String = Shader.compile_success(object: shader, stage: GL_COMPILE_STATUS,
                                                         status:{ glGetShaderiv(shader: $0,
                                                                                pname : $1,
                                                                                params: $2)
                                                                },
                                                         log   :{ glGetShaderInfoLog(shader : $0,
                                                                                     bufSize: $1,
                                                                                     length : $2,
                                                                                     infoLog: $3)
                                                                })
        {
            print(error_msg)
            return nil
        }
        else
        {
            return shader
        }
    }

    private static
    func link(program:GLuint, shaders:[GLuint]) -> Bool
    {
        for shader in shaders
        {
            glAttachShader(program, shader)
            defer { glDeleteShader(shader: shader) }
        }
        glLinkProgram(program: program)

        if let error_msg:String = Shader.compile_success(object: program, stage: GL_LINK_STATUS,
                                                         status: { glGetProgramiv($0, $1, $2) },
                                                         log   : { glGetProgramInfoLog($0, $1, $2, $3) })
        {
            print(error_msg)
            return false
        }
        else
        {
            return true
        }
    }

    private static
    func compile_success(object:GLuint, stage:GLenum, status:Status_func, log:Log_func) -> String?
    {
        var success:GLint = 0
        status(object, stage, &success)
        if success == 1
        {
            return nil
        }
        else
        {
            var message_length:GLsizei = 0
            status(object, GL_INFO_LOG_LENGTH, &message_length)
            guard message_length > 0
            else
            {
                return ""
            }
            var error_message = [GLchar](repeating: 0, count: Int(message_length))
            log(object, message_length, &message_length, &error_message)
            return String(cString: error_message)
        }
    }
}
