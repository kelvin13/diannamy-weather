import func Glibc.sin
import func Glibc.cos

public
struct BallView
{
    public
    var center:Vector3D<Float>,
        θ:Float,
        φ:Float,
        ρ:Float

    public
    init(center:Vector3D<Float>, θ:Float = 0, φ:Float = 0, ρ:Float = 1)
    {
        self.center = center
        self.θ      = θ
        self.φ      = φ
        self.ρ      = ρ
    }

    public
    init(cx:Float = 0, cy:Float = 0, cz:Float = 0, θ:Float = 0, φ:Float = 0, ρ:Float = 1)
    {
        self.center = Vector3D(cx, cy, cz)
        self.θ      = θ
        self.φ      = φ
        self.ρ      = ρ
    }

    private
    var tangent:Vector3D<Float>
    {
        return Vector3D(-sin(self.θ), cos(self.θ), 0)
    }

    private
    var normal:Vector3D<Float>
    {
        return Vector3D(cos(self.θ) * sin(self.φ),
                        sin(self.θ) * sin(self.φ),
                        cos(self.φ))
    }

    private
    var position:Vector3D<Float>
    {
        return self.center.add(vector: self.normal, scaled_by: self.ρ)
    }

    public
    var position_and_view_matrix:(position:Vector3D<Float>, matrix:[Float])
    {
        let normal:Vector3D<Float>   = self.normal
        let tangent:Vector3D<Float>  = self.tangent
        let position:Vector3D<Float> = self.center.add(vector: normal, scaled_by: self.ρ) // avoid recalculating normal

        let bitangent:Vector3D<Float> = normal.cross(tangent)
        let view_matrix:[Float] =
        [tangent.x           ,  bitangent.x           ,  normal.x           , 0,
         tangent.y           ,  bitangent.y           ,  normal.y           , 0,
         tangent.z           ,  bitangent.z           ,  normal.z           , 0,
        -(tangent * position), -(bitangent * position), -(normal * position), 1]

        return (position: position, matrix: view_matrix)
    }
}

public
struct Transform
{
    private
    var scale_factor:Float,
        rotation:Quaternion,
        translation_vector:Vector3D<Float>

    public
    var model_matrix:[Float],
        model_inverse:[Float],
        rotation_matrix:[Float]

    public
    init(scale:Float = 1,
         rotations:[Quaternion] = [],
         translation_vector:Vector3D<Float> = Vector3D(0, 0, 0))
    {
        self.scale_factor = scale
        self.rotation = rotations.reduce(Quaternion(), *)
        self.translation_vector = translation_vector

        self.rotation_matrix = self.rotation.matrix()
        self.model_matrix  = Transform.matrix(scale: scale,
                                              rotation: self.rotation_matrix,
                                              translation: translation_vector)
        self.model_inverse = Transform.inverse_matrix(scale: scale,
                                                      rotation: self.rotation_matrix,
                                                      translation: translation_vector)
    }

    public mutating
    func rotate(by rotations:Quaternion...)
    {
        self.rotation = rotations.reduce(self.rotation, *).unit()
    }

    public mutating
    func update_matrices()
    {
        self.rotation_matrix = self.rotation.matrix()
        self.model_matrix  = Transform.matrix(scale: self.scale_factor,
                                              rotation: self.rotation_matrix,
                                              translation: self.translation_vector)
        self.model_inverse = Transform.inverse_matrix(scale: self.scale_factor,
                                                      rotation: self.rotation_matrix,
                                                      translation: self.translation_vector)
    }

    private static
    func matrix(scale:Float, rotation:[Float], translation:Vector3D<Float>) -> [Float]
    {
        return [scale*rotation[0]   , scale*rotation[1] , scale*rotation[2] , 0,
                scale*rotation[3]   , scale*rotation[4] , scale*rotation[5] , 0,
                scale*rotation[6]   , scale*rotation[7] , scale*rotation[8] , 0,
                translation.x       , translation.y     , translation.z     , 1]
    }

    private static
    func inverse_matrix(scale:Float, rotation:[Float], translation:Vector3D<Float>) -> [Float]
    {
        let factor:Float = 1/scale
        let A:Float = rotation[0]*factor,
            B:Float = rotation[1]*factor,
            C:Float = rotation[2]*factor,
            D:Float = rotation[3]*factor,
            E:Float = rotation[4]*factor,
            F:Float = rotation[5]*factor,
            G:Float = rotation[6]*factor,
            H:Float = rotation[7]*factor,
            I:Float = rotation[8]*factor
        return [A                                 , D                                   , G                                 , 0,
                B                                 , E                                   , H                                 , 0,
                C                                 , F                                   , I                                 , 0,
                -(translation * Vector3D(A, B, C)), -(translation * Vector3D(D, E, F))  , -(translation * Vector3D(G, H, I)), 1]
    }

}
