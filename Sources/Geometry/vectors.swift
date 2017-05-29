import func Glibc.sin
import func Glibc.cos

public
struct Vector3D<FloatType:FloatingPoint>
{
    public
    let x:FloatType,
        y:FloatType,
        z:FloatType

    public
    init(_ x:FloatType, _ y:FloatType, _ z:FloatType)
    {
        self.x = x
        self.y = y
        self.z = z
    }

    public
    var magnitude:FloatType
    {
        return (self.x*self.x + self.y*self.y + self.z*self.z).squareRoot()
    }

    public
    var unit:Vector3D<FloatType>
    {
        let f:FloatType = 1/self.magnitude
        return Vector3D(self.x*f, self.y*f, self.z*f)
    }

    public
    func cross(_ b:Vector3D<FloatType>) -> Vector3D<FloatType>
    {
        return Vector3D(self.y*b.z - b.y*self.z, self.z*b.x - b.z*self.x, self.x*b.y - b.x*self.y)
    }

    func adding_dot_product(_ a:Vector3D<FloatType>, _ b:Vector3D<FloatType>) -> Vector3D<FloatType>
    {
        return Vector3D(self.x.addingProduct(a.x, b.x), self.y.addingProduct(a.y, b.y), self.z.addingProduct(a.z, b.z))
    }

    func add(vector:Vector3D<FloatType>, scaled_by k:FloatType) -> Vector3D<FloatType>
    {
        return Vector3D(self.x.addingProduct(vector.x, k), self.y.addingProduct(vector.y, k), self.z.addingProduct(vector.z, k))
    }

    // custom operators

    public static
    func * (_ a:Vector3D<FloatType>, _ b:Vector3D<FloatType>) -> FloatType
    {
        return a.x*b.x + a.y*b.y + a.z*b.z
    }

    public static
    func * (_ a:FloatType, _ b:Vector3D<FloatType>) -> Vector3D<FloatType>
    {
        return Vector3D(a*b.x, a*b.y, a*b.z)
    }

    public static
    func - (_ a:Vector3D<FloatType>, _ b:Vector3D<FloatType>) -> Vector3D<FloatType>
    {
        return Vector3D(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    public static
    func + (_ a:Vector3D<FloatType>, _ b:Vector3D<FloatType>) -> Vector3D<FloatType>
    {
        return Vector3D(a.x + b.x, a.y + b.y, a.z + b.z)
    }
}

public
struct Quaternion
{
    private
    let x:Float,
        y:Float,
        z:Float,
        w:Float

    private
    var length:Float
    {
        return (x*x + y*y + z*z + w*w).squareRoot()
    }

    private
    init(_ w:Float, _ x:Float, _ y:Float, _ z:Float) // private to prevent invalid quaternions from being created
    {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    init()
    {
        self.init(1, 0, 0, 0)
    }

    public
    init(_ axis:Vector3D<Float>, _ θ:Float)
    {
        let angle = θ*0.5
        let scale = sin(angle)
        self.init(cos(angle), axis.x*scale, axis.y*scale, axis.z*scale)
    }

    func matrix() -> [Float]
    {
        let xx  = self.x * self.x,
            yy  = self.y * self.y,
            zz  = self.z * self.z,

            xy2 = 2 * self.x * self.y,
            xz2 = 2 * self.x * self.z,
            yz2 = 2 * self.y * self.z,
            wx2 = 2 * self.w * self.x,
            wy2 = 2 * self.w * self.y,
            wz2 = 2 * self.w * self.z
        //fill in the first row
        return [1 - 2*(yy + zz) , xy2 + wz2         , xz2 - wy2     ,
                xy2 - wz2       , 1 - 2*(xx + zz)   , yz2 + wx2     ,
                xz2 + wy2       , yz2 - wx2         , 1 - 2*(xx + yy)]
    }

    func unit() -> Quaternion
    {
        let norm = 1/self.length
        return Quaternion(self.w*norm, self.x*norm, self.y*norm, self.z*norm)
    }

    static
    func * (lhs:Quaternion, rhs:Quaternion) -> Quaternion
    {
        return Quaternion(  rhs.w*lhs.w - rhs.x*lhs.x - rhs.y*lhs.y - rhs.z*lhs.z,
                            rhs.w*lhs.x + rhs.x*lhs.w - rhs.y*lhs.z + rhs.z*lhs.y,
                            rhs.w*lhs.y + rhs.z*lhs.z + rhs.y*lhs.w - rhs.z*lhs.x,
                            rhs.w*lhs.z - rhs.x*lhs.y + rhs.y*lhs.x + rhs.z*lhs.w
                          )
    }
}
