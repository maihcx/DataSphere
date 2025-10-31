namespace DataSphere.Services.Database.Builder
{
    public class SelectBuilder
    {
        private readonly List<string> _columns = new();
        private string? _table;
        private string? _where;
        private string? _orderBy;
        private int? _limit;

        public SelectBuilder Select(params string[] columns)
        {
            _columns.AddRange(columns);
            return this;
        }

        public SelectBuilder From(string table)
        {
            _table = table;
            return this;
        }

        public SelectBuilder Where(string condition)
        {
            _where = condition;
            return this;
        }

        public SelectBuilder OrderBy(string clause)
        {
            _orderBy = clause;
            return this;
        }

        public SelectBuilder Limit(int count)
        {
            _limit = count;
            return this;
        }

        public string ToSqlString()
        {
            if (string.IsNullOrEmpty(_table))
                throw new InvalidOperationException("No table specified for SELECT query.");

            var sb = new StringBuilder("SELECT ");

            sb.Append(_columns.Count > 0 ? string.Join(", ", _columns) : "*");
            sb.Append(" FROM ").Append(_table);

            if (!string.IsNullOrEmpty(_where))
                sb.Append(" WHERE ").Append(_where);

            if (!string.IsNullOrEmpty(_orderBy))
                sb.Append(" ORDER BY ").Append(_orderBy);

            if (_limit.HasValue)
                sb.Append(" LIMIT ").Append(_limit.Value);

            sb.Append(';');
            return sb.ToString();
        }
    }
}
