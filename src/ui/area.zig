//! An `Area` is a 2d area defined by its top left and bottom right.
//!
//! Invariant: bottom right is greater than top left. This is enforced via
//! debug assertions.

/// `Pos` are 4-byte x and y coordinate pairs. This restriction allows an
/// `Area` to fit in a single register.
///
/// See also:
/// * `Area`
pub const Pos = struct {
    x: u16,
    y: u16,
};

/// Like `Pos`, but defines a width and height pair.
pub const Bounded = struct {
    width: u32,
    height: u32,
};

/// `Area` are an 8-byte coordinate pair defining a rectangular bounding box.
pub const Area = struct {
    tl: Pos,
    br: Pos,

    /// Determines if two areas collide.
    pub fn overlaps(self: Area, other: Area) bool {
        return !(
            self.br.x <= other.tl.x or // self is left of other
            self.tl.x >= other.br.x or // self is right of other
            self.br.y <= other.tl.y or // self is above other
            self.tl.y >= other.br.y    // self is below other
        );
    }

    /// Determines if this area entirely encompasses the other.
    pub fn contains(self: Area, other: Area) bool {
        return self.tl.x <= other.tl.x and
               self.tl.y <= other.tl.y and
               self.br.x >= other.br.x and
               self.br.y >= other.br.y;
    }
};
